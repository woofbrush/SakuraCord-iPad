import MediaPipeline
import ReplayKit

/// Entry point of the Broadcast Upload extension. All capture work lives in
/// `ScreenShareBroadcastUplink`; this only adapts ReplayKit's callbacks.
@objc(SampleHandler)
final class SampleHandler: RPBroadcastSampleHandler, @unchecked Sendable {
    private var uplink: ScreenShareBroadcastUplink?

    override func broadcastStarted(withSetupInfo _: [String: NSObject]?) {
        let uplink = ScreenShareBroadcastUplink { [weak self] message in
            self?.finishBroadcastWithError(NSError(
                domain: "dev.sakuracord.broadcast",
                code: 1,
                userInfo: [NSLocalizedFailureReasonErrorKey: message]
            ))
        }
        self.uplink = uplink
        uplink.start()
    }

    override func processSampleBuffer(_ sampleBuffer: CMSampleBuffer, with type: RPSampleBufferType) {
        switch type {
        case .video: uplink?.processVideo(sampleBuffer)
        case .audioApp: uplink?.processAudio(sampleBuffer)
        default: break
        }
    }

    override func broadcastFinished() {
        uplink?.stop()
        uplink = nil
    }
}
