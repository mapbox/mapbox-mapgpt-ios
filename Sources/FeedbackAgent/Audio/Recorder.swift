import AVFoundation
import MapboxCommonGpt

public enum RecordingState {
    case recording, paused, stopped
}

public struct RecorderError: Error {
    static let formatPcmFormatInt16Unavailable = Self()
    static let sampleRateMismatch = Self()
}

// MARK: -

@_spi(ExperimentalMapboxAPI)
public class Recorder {
    public static let sampleRate: Double = AVAudioSession.sharedInstance().sampleRate

    private var engine = AVAudioEngine()
    private let bus = AVAudioNodeBus()

    public private(set) var state: RecordingState = .stopped

    public required init() {}

    /// Must be called immediately before recording
    private func activateSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.record, mode: .default)
        } catch {
            Log.error(
                "Failed to set audio session category to recording. \(error.localizedDescription)",
                category: .audio
            )
            return
        }
        do {
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            Log.error("Failed to activate audio session. \(error.localizedDescription)", category: .audio)
        }
    }
}

public extension Recorder {
    func startRecording(with feedbackAgentSession: FeedbackAgentSession) throws {
        activateSession()

        #if targetEnvironment(simulator)
            // Simulator does not support microphone recording
            return
        #endif
        let inputNode = engine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: bus)

        guard let outputFormat = AVAudioFormat(
            commonFormat: AVAudioCommonFormat.pcmFormatInt16,
            sampleRate: Recorder.sampleRate,
            channels: 1,
            interleaved: false
        ) else {
            Log.error(
                "Failed to create AVAudioFormat with pcmFormatInt16 at sample rate \(Recorder.sampleRate)",
                category: .audio
            )
            return
        }

        Log.debug(
            "Starting recording with recording format \(recordingFormat), with format description \(recordingFormat.formatDescription)",
            category: .audio
        )
        Log.debug(
            "Starting recording with output format \(outputFormat), format description \(outputFormat.formatDescription), with common format \(outputFormat.commonFormat)",
            category: .audio
        )

        guard feedbackAgentSession.options.sampleRate == UInt32(Self.sampleRate) else {
            Log.error(
                "Sample rate configured in session options (\(feedbackAgentSession.options.sampleRate)) does not match the sample rate of the Recorder (\(Self.sampleRate))",
                category: .audio
            )
            return
        }

        let frameCapacity = UInt32(recordingFormat.settings.capacity)
        let bytesPerFrame = Int(recordingFormat.streamDescription.pointee.mBytesPerFrame)
        let bitsPerChannel = recordingFormat.streamDescription.pointee.mBitsPerChannel
        let totalCapacity = frameCapacity * UInt32(bytesPerFrame) * bitsPerChannel

        let recordingTapBufferSize = AVAudioFrameCount(totalCapacity)

        Log.debug("mChannelsPerFrame=\(recordingFormat.streamDescription.pointee.mChannelsPerFrame) (should be 1)", category: .audio)
        Log.debug("mBitsPerChannel=\(outputFormat.streamDescription.pointee.mBitsPerChannel) (should be 16 for pcmFormatInt16)", category: .audio)

        inputNode.installTap(onBus: bus, bufferSize: recordingTapBufferSize, format: outputFormat) { [asrSession = feedbackAgentSession.session] recordingBuffer, _ in
            if let int16ChannelData = recordingBuffer.int16ChannelData {
                let data = Data(
                    bytes: int16ChannelData[0],
                    count: Int(recordingBuffer.frameLength)
                )
                asrSession.sendAsrData(for: data)
                Log.info("↑ Uploaded \(data)", category: .audio)
            } else {
                Log.debug(
                    "Failed to find int16ChannelData from recording buffer, something went wrong with recording buffer.",
                    category: .audio
                )
            }
        }

        engine.prepare()
        try engine.start()
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            state = .recording
        }
    }
}

public extension Recorder {
    func resumeRecording() throws {
        try engine.start()
        state = .recording
    }

    func pauseRecording() {
        engine.pause()
        state = .paused
    }

    func stopRecording() {
        engine.stop()
        #if !targetEnvironment(simulator)
            // Simulator does not support microphone recording
            engine.inputNode.removeTap(onBus: bus)
        #endif
        state = .stopped
    }
}
