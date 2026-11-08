#if os(iOS)
import AVFoundation
import Foundation

/// iOS has no addressable audio devices; AVAudioSession owns routing. Each port
/// in the current session gets a stable index so device menus keep working.
public typealias AudioDeviceID = UInt32

let kAudioDeviceTransportTypeBluetooth: UInt32 = 0x626C_7565 // 'blue'
let kAudioDeviceTransportTypeBluetoothLE: UInt32 = 0x626C_6561 // 'blea'
let kAudioDeviceTransportTypeBuiltIn: UInt32 = 0x626C_746E // 'bltn'
let kAudioDeviceTransportTypeVirtual: UInt32 = 0x7669_7274 // 'virt'
let kAudioDeviceTransportTypeAggregate: UInt32 = 0x6772_7570 // 'grup'

/// iPadOS has no screen-recording permission for in-app capture of other apps.
func CGPreflightScreenCaptureAccess() -> Bool { false }

public enum MediaDeviceCatalog {
    public static func snapshot() -> MediaDeviceSnapshot {
        let session = AVAudioSession.sharedInstance()
        let currentInput = session.currentRoute.inputs.first?.uid
        let inputs = (session.availableInputs ?? []).enumerated().map { index, port in
            info(port, id: AudioDeviceID(index + 1), isDefault: port.uid == currentInput)
        }
        let outputs = session.currentRoute.outputs.enumerated().map { index, port in
            info(port, id: AudioDeviceID(index + 1), isDefault: index == 0)
        }
        let defaultCameraID = AVCaptureDevice.default(for: .video)?.uniqueID
        let cameras = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .external],
            mediaType: .video,
            position: .unspecified
        ).devices.map {
            CameraDeviceInfo(uniqueID: $0.uniqueID, name: $0.localizedName, isDefault: $0.uniqueID == defaultCameraID)
        }
        return MediaDeviceSnapshot(audioInputs: inputs, audioOutputs: outputs, cameras: cameras)
    }

    public static func camera(uniqueID: String?) -> AVCaptureDevice? {
        guard let uniqueID, !uniqueID.isEmpty else { return AVCaptureDevice.default(for: .video) }
        return AVCaptureDevice(uniqueID: uniqueID)
    }

    static func audioCaptureDevice(deviceID _: AudioDeviceID?) -> AVCaptureDevice? {
        AVCaptureDevice.default(for: .audio)
    }

    public static func selectInput(_ deviceID: AudioDeviceID, on _: AVAudioEngine) throws {
        let session = AVAudioSession.sharedInstance()
        guard let port = session.availableInputs?[safe: Int(deviceID) - 1] else { return }
        try session.setPreferredInput(port)
    }

    /// Output routing belongs to the system route picker on iOS.
    public static func selectOutput(_: AudioDeviceID, on _: AVAudioEngine, reselectCurrentDevice _: Bool = true) throws {}

    public static func defaultOutputDeviceID() -> AudioDeviceID? { 1 }

    public static func defaultInputDeviceID() -> AudioDeviceID? { 1 }

    private static func info(_ port: AVAudioSessionPortDescription, id: AudioDeviceID, isDefault: Bool) -> AudioDeviceInfo {
        let transport: UInt32 = switch port.portType {
        case .bluetoothA2DP, .bluetoothHFP: kAudioDeviceTransportTypeBluetooth
        case .bluetoothLE: kAudioDeviceTransportTypeBluetoothLE
        case .builtInMic, .builtInSpeaker, .builtInReceiver: kAudioDeviceTransportTypeBuiltIn
        default: 0
        }
        return AudioDeviceInfo(id: id, uid: port.uid, name: port.portName, isDefault: isDefault, transportType: transport)
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? { indices.contains(index) ? self[index] : nil }
}

/// Reports AVAudioSession route changes, matching the macOS hot-plug monitor.
public final class MediaDeviceMonitor: @unchecked Sendable {
    public typealias Handler = @Sendable (MediaDeviceSnapshot) -> Void

    private let observer: any NSObjectProtocol

    public init(handler: @escaping Handler) {
        observer = NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification, object: nil, queue: nil
        ) { _ in handler(MediaDeviceCatalog.snapshot()) }
        DispatchQueue.global(qos: .userInitiated).async { handler(MediaDeviceCatalog.snapshot()) }
    }

    deinit {
        NotificationCenter.default.removeObserver(observer)
    }
}
#endif
