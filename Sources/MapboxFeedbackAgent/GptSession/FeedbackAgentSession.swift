import AVFoundation
import Foundation
import MapboxCommon
@_implementationOnly import MapboxCommon_Private
@preconcurrency import MapboxCommonGpt
@preconcurrency import MapboxCommonGpt_Private
@_spi(MapboxInternal) import MapboxCoreNavigation

@_spi(ExperimentalMapboxAPI)
public protocol FeedbackAgentSessionDelegate: NSObjectProtocol {
    /// Invocations are not guaranteed to run on the main thread.
    func feedbackAgent(session: FeedbackAgentSession, didChangeState state: FeedbackAgentSessionState)
    /// Called when a single new String is added. The entire session transcript is kept in ``FeedbackAgentSession/transcriptContents``.
    func feedbackAgent(session: FeedbackAgentSession, didReceiveTranscript transcript: String, isFinal: Bool)
    func feedbackAgent(session: FeedbackAgentSession, didComplete: Result<UUID, Error>)
}

// MARK: -

@_spi(ExperimentalMapboxAPI)
public class FeedbackAgentSession {
    // MARK: - GPT Session

    /// MapboxCommonGpt object that provides foundational cross-platform functionality.
    var session: MapgptSession

    public weak var delegate: FeedbackAgentSessionDelegate?

    /// Provide the current state, useful for receiving UI updates.
    /// Across the lifetime of a FeedbackAgentSession each state can be reached more than once.
    /// That is: you can re-use a session object to start a new ASR request.
    /// Terminal values signifying the end of a session include: ``FeedbackAgentSessionState/disconnected``,
    /// ``FeedbackAgentSessionState/successfullySubmitted(_:)``, and
    /// ``FeedbackAgentSessionState/failedToSubmit(_:)``.
    /// A `disconnected` state will be used for sessions that fail to reach the `connected` state (including situations
    ///  where something went wrong with a configuration, connection, permissions, network connectivity, or other reason
    ///  that prevented the session from starting).
    public private(set) var state = FeedbackAgentSessionState.disconnected

    /// Publish all received transcripts (including a "." for an empty transcript) to help debugging.
    /// Newer transcripts are inserted at the beginning of the array.
    /// When multiple empty transcripts are received they are appended to the newest empty transcript (index 0) to avoid
    /// clutter. (ex: ".....").
    public private(set) var transcriptContents: [String] = []

    // MARK: - Audio

    public private(set) var recorder: Recorder

    // MARK: - Operations and Concurrency

    /// DispatchQueue to run non-UI operations on.
    var workQueue: DispatchQueue
    /// When ``FeedbackAgentSession/workQueue`` tasks are completed, updates to fields must be done on the main queue.
    private var updateQueue = DispatchQueue.main
    /// DispatchGroup to enforce ordering of essential session connection tasks.
    private var connectionGroup: DispatchGroup
    /// DispatchGroup to enforce ordering of essential audio recording tasks.
    private var asrGroup: DispatchGroup
    /// Used to check if a session connection request should timeout and fail. (ex: no internet connection).
    private var connectCancellationTimer: Timer?
    /// Used to check if an ASR (automatic speech recognition) request should timeout and fail.
    private var asrCancellationTimer: Timer?

    // MARK: UI Display

    /// Convenience output (equivalent to querying `state == .recording`) to update UI when the session is recording.
    public var displayRecordingAnimation: Bool {
        switch state {
        case .recording:
            true
        default:
            false
        }
    }

    /// Convenience output (equivalent to querying `state < .recording`) to update UI title/subtitle/close-button.
    public var displayTitle: Bool {
        switch state {
        case .completed:
            false
        default:
            true
        }
    }

    /// Convey if the requirements are met to start an ASR session.
    public var ready: Bool {
        userContext != nil
    }

    // MARK: Session Values

    /// Convey if any errors have occurred within this session.
    /// It is not necessary to destroy the FeedbackAgentSession object to recover from an error.
    /// After an error occurs you will need to start a new connection (with ``start()`` or ``autoConnect()``)
    /// to report another feedback item.
    public private(set) var error: MapgptSessionError?

    public private(set) var navigationMode: NavigationMode

    var eventsProvider = EventsAPIProvider()

    /// Passive events manager for use in Free Drive or outside of active navigation.
    /// Required during passive navigation.
    public var passiveEventsManager: NavigationEventsManager? {
        didSet {
            if passivePendingFeedback == nil {
                Log.error("Assigning FeedbackAgentSession.passiveEventsManager to nil before passivePendingFeedback was sent is an error.", category: .feedback)
            }
            if activeEventsManager != nil {
                navigationMode = .active
            } else {
                navigationMode = .passive
            }
        }
    }

    /// Passive pending feedback for use in Free Drive or outside of active navigation.
    /// Will be populated and used exclusively during passive navigation.
    public private(set) var passivePendingFeedback: FeedbackEvent?

    /// Active events manager for use in active navigation.
    /// Required during active navigation.
    public var activeEventsManager: NavigationEventsManager? {
        didSet {
            if passivePendingFeedback == nil {
                Log.error("Assigning FeedbackAgentSession.activeEventsManager to nil before activePendingFeedback was sent is an error.", category: .feedback)
            }
            if activeEventsManager != nil {
                navigationMode = .active
            } else {
                navigationMode = .passive
            }
        }
    }

    /// Active pending feedback for use in active navigation.
    /// Will be populated and used exclusively during active navigation.
    public private(set) var activePendingFeedback: FeedbackEvent?

    /// Hook for clients to receive when a Feedback Report is completed.
    /// After this block is invoked you will need to start a new connection (with ``start()`` or ``autoConnect()``)
    /// to report another feedback item.
    public var feedbackReporter: (VoiceFeedbackItem) -> Void = { _ in }

    /// Hook for clients to receive when a Feedback Report is completed.
    /// After this value is received you will need to start a new connection (with ``start()`` or ``autoConnect()``)
    /// to report another feedback item.
    public var feedbackReport: VoiceFeedbackItem?

    // MARK: - Inputs

    /// Provides essential session context such as ``Context/location`` to report feedback.
    /// Required to be non-nil before invoking ``startASR()``.
    /// This will be used as part of ``FeedbackAgentSession/contextDictionary`` to provide context to the session requests.
    public var userContext: Context?

    /// Provides essential session context.
    /// Requires ``FeedbackAgentSession/userContext`` value for its `user_context` key.
    private var contextDictionary: [String: [String: String]] = [
        "app_context": [
            "locale": Locale.current.languageCode?.lowercased() ?? "en",
        ],
        // "user_context": ["lat": "0.0", "lon": "0.0", "place_name": "", ...]
    ]

    /// Configuration options to control setting up this MapGpt session.
    /// For example determine if this is a text (chat) session, or ASR (automatic speech recognition), or both modes
    /// together.
    /// Presets can be found at `MapgptSessionOptions+Presets.swift`.
    public private(set) var options: MapgptSessionOptions

    /// Designated-public initializer to create a FeedbackAgentSession instance.
    /// To begin using a session invoke ``start()`` or ``autoConnect()``.
    /// After a session reaches a terminal state (``FeedbackAgentSessionState/completed(_:)``,
    /// or ``FeedbackAgentSessionState/disconnected``) you can begin a new request
    /// by calling ``start()`` or ``autoConnect()`` again.
    /// - Parameters:
    ///   - passiveEventsManager: Injected from MapboxCoreNavigation to provide telemetry and event reporting capabilities aligned with navigation.
    ///   - activeEventsManager: Injected from MapboxCoreNavigation to provide telemetry and event reporting capabilities aligned with navigation.
    ///   - options: The configuration options for this session. Constant for the lifetime of the session object.
    ///   See ``MapgptSessionOptions`` for more details.
    ///   - userContext: The user context for whoever is running the application and using this MapGpt session to provide feedback. The ``FeedbackAgentSession/userContext`` is **required** to have a value before invoking ``start()`` or ``autoConnect()``.
    ///   - recorder: An instance of ``Recorder`` which will provide audio input.
    public convenience init(
        passiveEventsManager: NavigationEventsManager,
        activeEventsManager: NavigationEventsManager,
        options: MapgptSessionOptions = .feedbackASR,
        context userContext: Context? = nil,
        recorder: Recorder = Recorder()
    ) {
        self.init(
            passiveEventsManager: passiveEventsManager,
            activeEventsManager: activeEventsManager,
            options: options,
            context: userContext,
            recorder: recorder
        )
    }

    /// Convenience initializer to create a FeedbackAgentSession instance used only with passive navigation feedback.
    /// This requires providing location updates through `PassiveLocationManager` or manual location updates.
    public convenience init(
        passiveEventsManager: NavigationEventsManager,
        options: MapgptSessionOptions = .feedbackASR,
        context userContext: Context? = nil,
        recorder: Recorder = Recorder()
    ) {
        self.init(
            passiveEventsManager: passiveEventsManager,
            activeEventsManager: nil,
            options: options,
            context: userContext,
            recorder: recorder
        )
    }

    /// Convenience initializer to create a FeedbackAgentSession instance used only with active navigation feedback.
    /// This requires providing location updates through manual location updates.
    public convenience init(
        activeEventsManager: NavigationEventsManager,
        options: MapgptSessionOptions = .feedbackASR,
        context userContext: Context? = nil,
        recorder: Recorder = Recorder()
    ) {
        self.init(
            passiveEventsManager: nil,
            activeEventsManager: activeEventsManager,
            options: options,
            context: userContext,
            recorder: recorder
        )
    }

    /// Internal designated initializer to create a FeedbackAgentSession instance.
    /// - Parameters:
    ///   - passiveEventsManager: Injected from MapboxCoreNavigation to provide telemetry
    ///   - activeEventsManager: Injected from MapboxCoreNavigation to provide telemetry
    ///   - options: The configuration options for this session.
    ///   - userContext: The user context for whoever is running this application and using Feedback Agent. Must be updated when the device location changes for accurate event reporting.
    ///   - recorder: An instance of ``Recorder`` which will provide audio input.
    init(
        passiveEventsManager: NavigationEventsManager?,
        activeEventsManager: NavigationEventsManager?,
        options: MapgptSessionOptions = .feedbackASR,
        context userContext: Context? = nil,
        recorder: Recorder = Recorder()
    ) {
        self.passiveEventsManager = passiveEventsManager
        self.activeEventsManager = activeEventsManager
        if activeEventsManager != nil {
            navigationMode = .active
        } else {
            navigationMode = .passive
        }
        session = MapgptSession()
        self.options = options
        workQueue = DispatchQueue(
            label: "com.mapbox.mapgpt.sessionobserver",
            target: .global(qos: .userInitiated)
        )
        connectionGroup = DispatchGroup()
        asrGroup = DispatchGroup()
        self.userContext = userContext
        self.recorder = recorder
        if let userContext {
            contextDictionary["user_context"] = userContext.dictionary
        }
    }

    /// Begin a FeedbackAgentSession connection. If a lack of network connectivity, misconfigured options, or other failure
    /// prevents establishing the connection then it will time out after 30 seconds.
    /// This is **required** before you can use text chat.
    /// This is **required** before you invoke ``startASR()`` for an ASR session.
    /// You may re-use an existing session object by calling ``start()`` again after successfully closing an earlier
    /// request, or a failure occurs.
    public func start() {
        start(navigationMode: navigationMode)
    }

    /// Begin a FeedbackAgentSession connection. If a lack of network connectivity, misconfigured options, or other failure
    /// prevents establishing the connection then it will time out after 30 seconds.
    /// This is **required** before you can use text chat.
    /// This is **required** before you invoke ``startASR()`` for an ASR session.
    /// You may re-use an existing session object by calling ``start()`` again after successfully closing an earlier
    /// request, or a failure occurs.
    /// - Parameter navigationMode: If both activeEventsManager and passiveEventsManager are not-nil, use navigationMode parameter to specify which one will be used.
    public func start(navigationMode: NavigationMode) {
        if let activeEventsManager, navigationMode == .active {
            activePendingFeedback = activeEventsManager.createFeedback(screenshotOption: .automatic)
            passivePendingFeedback = nil
        } else if let passiveEventsManager, navigationMode == .passive {
            activePendingFeedback = nil
            passivePendingFeedback = passiveEventsManager.createFeedback(screenshotOption: .automatic)
        } else {
            assertionFailure("FeedbackAgentSession cannot proceed without an eventsManager")
            return
        }

        connectionGroup.enter()
        updateQueue.async { [weak self] in
            self?.state = .connecting
        }

        connectCancellationTimer?.invalidate()
        connectCancellationTimer = nil
        session.connect(for: options, observer: self)

        let timeoutInterval: TimeInterval = 30
        connectCancellationTimer = Timer.scheduledTimer(
            timeInterval: timeoutInterval,
            target: self,
            selector: #selector(connectionRequestDidTimeOut(_:)),
            userInfo: nil,
            repeats: false
        )
    }

    /// Begin using ASR (automatic speech recognition).
    /// Prerequisites:
    /// - requires ``start()`` to be invoked before ``startASR()``.
    /// - requires ``userContext`` to have a value.
    /// Alternatively ``autoConnect()`` can be used to achieve both start+startASR together.
    private func startASR() {
        guard let userContext else {
            Log.error("\(#function) error: \(error)", category: .audio)
            state = .completed(.failure(GptError.missingLocationContext))
            delegate?.feedbackAgent(session: self, didComplete: .failure(GptError.missingLocationContext))
            return
        }

        contextDictionary["user_context"] = userContext.dictionary

        Log.debug(
            "\(#function) - Starting ASR with context \(type(of: contextDictionary)): \(contextDictionary)",
            category: .session
        )

        session.startAsrRequest(
            forContext: contextDictionary,
            capabilities: [],
            profile: nil
        )
        asrGroup.leave()
    }

    /// Recommended entry-point to connect to a ``FeedbackAgentSession``.
    /// ``autoConnect()`` will perform each required step to establish an ASR (automatic speech recognition) session
    /// and update the UI values to reflect the status at each moment.
    public func autoConnect(autoRecord: Bool) {
        transcriptContents = []

        asrGroup.enter()
        start(navigationMode: navigationMode)

        connectionGroup.notify(queue: workQueue) { [weak self] in
            guard let self else { return }

            startASR()

            asrGroup.notify(queue: workQueue) { [weak self] in
                self?.requestMicrophonePermission(recordAudio: autoRecord)
            }
        }
    }

    /// Stateful asynchronous helper to ensure microphone permissions are appropriate for ASR in this session.
    /// Will disconnect and the session if permissions are denied.
    /// - Parameter shouldRecordAudio: Whether recording should begin after permission is granted, or exit plainly.
    private func requestMicrophonePermission(recordAudio shouldRecordAudio: Bool) {
        updateQueue.async { [weak self] in
            self?.state = .requestingMicrophonePermission
        }

        AVAudioSession.sharedInstance().requestRecordPermission { [weak self] granted in
            guard let self else { return }
            if granted {
                if shouldRecordAudio {
                    recordAudio()
                }
            } else {
                disconnect(failure: GptError.notGrantedMicrophonePermission)
            }
        }
    }

    /// Begin an audio capture recording to fulfill the ASR (automatic speech recognition) request.
    public func recordAudio() {
        do {
            updateQueue.async { [weak self] in
                self?.state = .startingMicrophone
            }

            try recorder.startRecording(with: self)

            updateQueue.async { [weak self] in
                guard let self else { return }
                state = .recording
                delegate?.feedbackAgent(session: self, didChangeState: state)
            }
        } catch {
            Log.error("\(#function) error: \(error)", category: .audio)
            delegate?.feedbackAgent(session: self, didComplete: .failure(error))
        }
    }

    /// Manually end an ASR (automatic speech recognition) session, usually through user action.
    /// Not _required to be called_ in a session using MapgptSessionOptions.mode == MapgptSessionMode.offline because
    /// the server may detect a complete feedback report and signal that the feedback is complete which will stop
    /// recording.
    public func stopRecordingAndSend() {
        Log.debug("\(#function)", category: .audio)
        asrCancellationTimer?.invalidate()
        asrCancellationTimer = nil

        updateQueue.async { [weak self] in
            guard let self else { return }
            state = .submittingRecording

            recorder.stopRecording()
            session.finalizeAsrRequest(forAbort: false)

            let timeoutInterval: TimeInterval = 30
            asrCancellationTimer = Timer.scheduledTimer(
                timeInterval: timeoutInterval,
                target: self,
                selector: #selector(asrRequestDidTimeOut(_:)),
                userInfo: nil,
                repeats: false
            )
        }
    }

    /// End a session and close all inputs.
    /// - Parameter failure: A module-private value used to inform the UI of the reason for disconnecting this session.
    private func disconnect(failure: Error?) {
        Log.debug("\(#function) with failure?=\(String(describing: failure?.localizedDescription))", category: .session)
        connectCancellationTimer?.invalidate()
        connectCancellationTimer = nil

        recorder.stopRecording()

        let error = failure ?? GptError("Unknown error")

        session.cancelConnection { [weak self] result in
            self?.updateQueue.async { [weak self] in
                guard let self else { return }
                if let failure {
                    Log.error(
                        "\(#function) disconnected due to error \(failure.localizedDescription)",
                        category: .session
                    )
                    state = .completed(.failure(failure))
                    delegate?.feedbackAgent(session: self, didChangeState: state)
                    delegate?.feedbackAgent(session: self, didComplete: .failure(error))
                } else if result {
                    Log.debug("\(#function) disconnected successfully", category: .session)
                    state = .disconnected
                    delegate?.feedbackAgent(session: self, didChangeState: state)
                } else {
                    Log.error(
                        "\(#function) disconnected, but did not receive error or successful-disconnect",
                        category: .session
                    )
                    state = .disconnected
                    delegate?.feedbackAgent(session: self, didChangeState: state)
                    delegate?.feedbackAgent(session: self, didComplete: .failure(error))
                }
            }
        }
    }

    /// Close a session.
    public func disconnect() {
        disconnect(failure: nil)
    }

    // MARK: - Timeouts

    /// Respond to a session connection timeout, clean up the connections, and update the UI.
    /// - Parameter timer: The timer invoking the cancellation.
    @objc
    private func connectionRequestDidTimeOut(_ timer: Timer) {
        guard timer == connectCancellationTimer else {
            return
        }

        connectCancellationTimer?.invalidate()
        connectCancellationTimer = nil
        updateQueue.async { [weak self] in
            guard let self else { return }
            self.error = MapgptSessionError(type: .otherError, message: "Connection timeout")
            state = .completed(.failure(GptError.connectionTimeout))
            delegate?.feedbackAgent(session: self, didChangeState: state)
            delegate?.feedbackAgent(session: self, didComplete: .failure(GptError.connectionTimeout))
        }
    }

    /// Respond to an ASR session timeout, clean up the connections, and update the UI.
    /// - Parameter timer: The timer invoking the cancellation.
    @objc
    private func asrRequestDidTimeOut(_ timer: Timer) {
        guard timer == asrCancellationTimer else {
            return
        }

        asrCancellationTimer?.invalidate()
        asrCancellationTimer = nil
        updateQueue.async { [weak self] in
            guard let self else { return }
            error = MapgptSessionError(type: .otherError, message: "ASR timeout")
            state = .completed(.failure(GptError.asrTimeout))
            delegate?.feedbackAgent(session: self, didChangeState: state)
            delegate?.feedbackAgent(session: self, didComplete: .failure(GptError.asrTimeout))
        }
    }

    // MARK: - Handling feedback submission

    /// Called when a ``onMapgptMessageReceived(for:)`` provides a message with type equal to "feedback" to parse out.
    /// - Parameter message: The MapgptMessage input that contains feedback to parse and forward to the
    /// ``feedbackReporter``.
    private func processFeedback(from message: MapgptMessage) {
        guard let feedbackDict = message.data as? [String: String],
              let type = VoiceFeedbackType(string: feedbackDict["feedbackType"]!)
        else {
            Log.error("Failed to parse feedback data or type from \(message.data)", category: .feedback)
            return
        }

        let voiceFeedbackItem = VoiceFeedbackItem(
            description: feedbackDict["feedbackDescription"]!,
            feedbackType: type
        )

        cancelTimeouts()

        // TODO: NAVIOS-2502 Replace the FeedbackEventsObserver work-around with corrected sendActiveNavigationFeedback(completion:) function and sendPassiveNavigationFeedback(completion:)
        let event: Event
        if let activeEventsManager, let activePendingFeedback {
            event = activePendingFeedback.toEvent(with: voiceFeedbackItem)
        } else if let passiveEventsManager, let passivePendingFeedback {
            event = passivePendingFeedback.toEvent(with: voiceFeedbackItem)
        } else {
            Log.error("Failed to process feedback: pending feedback and corresponding events manager mismatch.", category: .feedback)
            disconnect(failure: GptError.feedbackError)
            return
        }

        eventsProvider.eventsAPI.sendEvent(for: event) { [weak self] result in
            guard let self else { return }
            updateQueue.async { [weak self] in
                guard let self else { return }
                if let result {
                    let telemetryError = GptError(result.message)
                    Log.error("Failed to submit feedback report due to telemetry error \(telemetryError)", category: .telemetry)
                    delegate?.feedbackAgent(session: self, didComplete: .failure(telemetryError))
                    return
                }
                Log.info("Successfully submitted feedback report \(voiceFeedbackItem.id)", category: .feedback)
                feedbackReporter(voiceFeedbackItem)
                feedbackReport = voiceFeedbackItem
                state = .completed(.success(voiceFeedbackItem))
                activePendingFeedback = nil
                passivePendingFeedback = nil
                delegate?.feedbackAgent(session: self, didChangeState: state)
            }
        }
    }

    #if DEBUG
        /// Send a pre-recorded audio file
        public func debug(with audioFile: AVAudioFile) {
            guard let buffer = AVAudioPCMBuffer(
                pcmFormat: audioFile.fileFormat,
                frameCapacity: AVAudioFrameCount(1_024_000)
            ) else {
                Log.error("Failed to create audio buffer in format \(audioFile.fileFormat)", category: .audio)
                return
            }

            workQueue.sync {
                assert(state == .recording)

                do {
                    while audioFile.framePosition < audioFile.length {
                        try audioFile.read(into: buffer)

                        if audioFile.fileFormat.channelCount == 1, let int16Channel = buffer.int16ChannelData {
                            let bytesPerFrame = buffer.format.streamDescription.pointee.mBytesPerFrame
                            let channels = Data(
                                bytes: int16Channel[0],
                                count: Int(buffer.frameLength * bytesPerFrame)
                            )

                            session.sendAsrData(for: channels)
                            Log.info("\(#function) ↑ Uploaded int16 \(channels)", category: .audio)
                        } else if audioFile.fileFormat.channelCount == 1, let floatChannel = buffer.floatChannelData {
                            let channels = Data(
                                bytes: floatChannel,
                                count: Int(buffer.frameCapacity)
                            )
                            session.sendAsrData(for: channels)
                            Log.info("\(#function) ↑ Uploaded float \(channels)", category: .audio)
                        } else {
                            Log.error("Could not find expected audio format from \(audioFile.fileFormat)", category: .audio)
                        }
                    }
                } catch {
                    Log.error("\(#function) failed to read from audio file, \(error)", category: .audio)
                }
                Log.debug("Exited \(#function) after uploading \(audioFile.url) pre-recorded resource", category: .audio)
            }
        }
    #endif

    /// A definitive state has been reached and all possible operation timeouts will no longer apply, cancel the timers.
    func cancelTimeouts() {
        asrCancellationTimer?.invalidate()
        asrCancellationTimer = nil
        connectCancellationTimer?.invalidate()
        connectCancellationTimer = nil
    }
}

extension FeedbackAgentSession: MapgptObserver {
    // MARK: - MapgptObserver Session Management

    /// Receive notice that the server connection has started.
    /// - Parameter startSession: Session information from the initiating request and the new connection.
    public func onMapgptSessionStarted(forMessage _: MapgptStartSession) {
        connectCancellationTimer?.invalidate()
        connectCancellationTimer = nil

        updateQueue.async { [weak self] in
            guard let self else { return }
            error = nil
            state = .connected
            connectionGroup.leave()
            delegate?.feedbackAgent(session: self, didChangeState: state)
        }
    }

    /// Receive notice that the server connection has encountered an error.
    /// - Parameter error: Error information.
    public func onMapgptSessionError(forError error: MapgptSessionError) {
        updateQueue.async { [weak self] in
            guard let self else { return }
            recorder.stopRecording()
            if state == .connecting {
                // connection failed
                connectCancellationTimer?.fire()
            } else {
                cancelTimeouts()
            }
            self.error = error
            state = .disconnected
            delegate?.feedbackAgent(session: self, didChangeState: state)
            delegate?.feedbackAgent(session: self, didComplete: .failure(GptError(error.description)))
        }
    }

    /// Receive notice that the server connection is reconnecting.
    /// - Parameter reconnecting: Session reconnection information.
    public func onMapgptSessionReconnecting(for reconnecting: MapgptSessionReconnecting) {
        Log.debug("\(#function) Session reconnecting \(reconnecting.description)", category: .session)
        updateQueue.async { [weak self] in
            guard let self else { return }
            state = .connecting
            delegate?.feedbackAgent(session: self, didChangeState: state)
        }
    }

    // MARK: - MapgptObserver Messages

    /// Receives _every_ message response from the GPT server, useful for displaying every partial response in realtime.
    /// Feedback reports are delivered in a single message.
    /// Use ``onMapgptConversationReceived(for:)`` to receive all messages together when final.
    /// - Parameter message: A single message responding to a user's query.
    public func onMapgptMessageReceived(for message: MapgptMessage) {
        // "Normally you should not use this and use onMapgptConversationReceived, onMapgptEntityReceived or
        // onMapgptActionReceived."
        Log.debug("\(#function) \(message.type), \(message)", category: .session)

        if message.type == "feedback" {
            processFeedback(from: message)
        }
    }

    /// Receive notice of a complete conversation containing multiple messages.
    /// - Parameter conversation: The conversation.
    public func onMapgptConversationReceived(for _: MapgptMessageConversation) {}

    /// Receive notice of a session entity.
    /// - Parameter entity: The entity.
    public func onMapgptEntityReceived(for _: MapgptMessageEntity) {}

    /// Receive notice of a session action.
    /// - Parameter action: The action.
    public func onMapgptActionReceived(for _: MapgptMessageAction) {}

    /// Receive notice of an ASR (automatic speech recognition) transcript.
    /// - Parameter transcript: The transcript
    public func onMapgptAsrTranscript(for transcript: MapgptAsrTranscript) {
        if transcript.isFinal {
            // The server has decided that this session is done so we can stop recording and close ASR.
            stopRecordingAndSend()
        }

        if !transcript.text.isEmpty {
            Log.debug("\(#function) \(transcript.isFinal ? "final " : "")'\(transcript.text)'", category: .session)
            updateQueue.sync { [weak self] in
                guard let self else { return }
                if transcript.isFinal {
                    transcriptContents.insert("<Final> " + transcript.text + "</Final>", at: 0)
                } else {
                    transcriptContents.insert(transcript.text, at: 0)
                }
            }
        } else {
            Log.debug("\(#function) empty transcript received", category: .session)
            // Stack up zeroes if there are any silences or empty transcripts
            updateQueue.sync { [weak self] in
                guard let self else { return }
                if let firstItem = transcriptContents.first, firstItem.hasSuffix(".") {
                    transcriptContents[0] = firstItem + "."
                } else {
                    transcriptContents.insert(".", at: 0)
                }
            }
        }

        DispatchQueue.main.async { [weak delegate] in
            // clients can check transcript.text.isEmpty on their own
            delegate?.feedbackAgent(session: self,
                                    didReceiveTranscript: transcript.text,
                                    isFinal: transcript.isFinal)
        }
    }
}
