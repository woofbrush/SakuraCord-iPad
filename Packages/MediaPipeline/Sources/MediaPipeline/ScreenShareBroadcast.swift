#if os(iOS)
import AVFoundation
@preconcurrency import CoreImage
import CoreMedia
import CoreVideo
import Foundation
import ImageIO
import Network
@preconcurrency import ReplayKit
import UIKit

/// iPadOS only lets a Broadcast Upload extension see the whole screen, and a
/// backgrounded app cannot use the hardware encoder. The extension therefore owns
/// capture and H.264/Opus encoding and streams finished frames to the app, which
/// feeds them into the same voice session path as the Mac capture engine.
///
/// The link is a loopback socket because an App Group's identifier does not survive
/// re-signing with a different team.
enum ScreenShareBroadcastWire {
    static let port: UInt16 = 48_621
    static let magic: UInt32 = 0x5343_4231
    static let maximumPayload = 32_000_000
    /// Matches the Mac engine: at most two reference frames between capture and UDP.
    static let maximumOutstandingVideoFrames = 2

    enum Kind: UInt8 {
        case hello = 1
        case video
        case audio
        case preview
        case configure = 10
        case keyframe
        case acknowledge
        case stop
    }

    struct Hello: Codable {
        var magic: UInt32
        var width: Int
        var height: Int
    }

    struct Configure: Codable, Equatable {
        var generation: UInt64
        var isEncoding: Bool
        var width: Int
        var height: Int
        var frameRate: Int
        var bitrate: Int
        var includesAudio: Bool
        var isPreviewEnabled: Bool
    }
}

private extension Data {
    mutating func appendWireInteger<Value: FixedWidthInteger>(_ value: Value) {
        Swift.withUnsafeBytes(of: value.bigEndian) { append(contentsOf: $0) }
    }

    func bigEndian<Value: FixedWidthInteger>(at offset: Int, as _: Value.Type = Value.self) -> Value? {
        guard offset >= 0, count >= offset + MemoryLayout<Value>.size else { return nil }
        return withUnsafeBytes { Value(bigEndian: $0.loadUnaligned(fromByteOffset: offset, as: Value.self)) }
    }
}

/// Length-prefixed messages over one loopback TCP connection.
final class ScreenShareBroadcastChannel: @unchecked Sendable {
    typealias Wire = ScreenShareBroadcastWire

    private let connection: NWConnection
    private let queue: DispatchQueue
    private let lock = NSLock()
    private var isClosed = false

    var onReady: (@Sendable () -> Void)?
    var onMessage: (@Sendable (Wire.Kind, Data) -> Void)?
    var onClose: (@Sendable () -> Void)?

    init(connection: NWConnection, queue: DispatchQueue) {
        self.connection = connection
        self.queue = queue
    }

    func start() {
        connection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready: self?.onReady?()
            case .failed, .cancelled: self?.didClose()
            default: break
            }
        }
        connection.start(queue: queue)
        readHeader()
    }

    func send(_ kind: Wire.Kind, _ payload: Data = Data(), completion: (@Sendable () -> Void)? = nil) {
        var packet = Data(capacity: payload.count + 5)
        packet.append(kind.rawValue)
        packet.appendWireInteger(UInt32(payload.count))
        packet.append(payload)
        connection.send(content: packet, completion: .contentProcessed { [weak self] error in
            if error != nil { self?.didClose() }
            completion?()
        })
    }

    func close() {
        connection.cancel()
    }

    private func didClose() {
        let first = lock.withLock { () -> Bool in
            defer { isClosed = true }
            return !isClosed
        }
        if first { onClose?() }
    }

    private func readHeader() {
        connection.receive(minimumIncompleteLength: 5, maximumLength: 5) { [weak self] data, _, _, error in
            guard let self else { return }
            guard error == nil, let data, data.count == 5,
                  let raw: UInt8 = data.bigEndian(at: 0),
                  let kind = Wire.Kind(rawValue: raw),
                  let length: UInt32 = data.bigEndian(at: 1),
                  length <= Wire.maximumPayload
            else {
                close()
                didClose()
                return
            }
            if length == 0 {
                onMessage?(kind, Data())
                readHeader()
            } else {
                readPayload(kind: kind, length: Int(length))
            }
        }
    }

    private func readPayload(kind: Wire.Kind, length: Int) {
        connection.receive(minimumIncompleteLength: length, maximumLength: length) { [weak self] data, _, _, error in
            guard let self else { return }
            guard error == nil, let data, data.count == length else {
                close()
                didClose()
                return
            }
            onMessage?(kind, data)
            readHeader()
        }
    }
}

// MARK: - App side

/// Presents the system broadcast picker and receives the extension's encoded media.
public final class ScreenShareCaptureEngine: NSObject, @unchecked Sendable {
    private typealias Wire = ScreenShareBroadcastWire

    public nonisolated let events: AsyncStream<ScreenShareCaptureEvent>
    public nonisolated let previewFrames: AsyncStream<VoiceVideoFrame>
    nonisolated let encodedFrames: AsyncStream<ScreenShareEncodedVideoFrame>
    public nonisolated let encodedAudioFrames: AsyncStream<CapturedOpusFrame>

    private let eventContinuation: AsyncStream<ScreenShareCaptureEvent>.Continuation
    private let previewContinuation: AsyncStream<VoiceVideoFrame>.Continuation
    private let encodedContinuation: AsyncStream<ScreenShareEncodedVideoFrame>.Continuation
    private let encodedAudioContinuation: AsyncStream<CapturedOpusFrame>.Continuation
    private let queue = DispatchQueue(label: "dev.sakuracord.screen-share.broadcast", qos: .userInitiated)
    private let lock = NSLock()
    private var settings: ScreenShareSettings
    private var sourceSize: CGSize?
    private var format: ScreenShareVideoFormat?
    private var isEncoding = false
    private var hasNetworkDemand = true
    private var isPreviewEnabled = true
    private var isStopped = false
    private var generation: UInt64 = 0
    private var listener: NWListener?
    private var channel: ScreenShareBroadcastChannel?
    private var pendingChannels: [ScreenShareBroadcastChannel] = []
    @MainActor private var pickerView: RPSystemBroadcastPickerView?

    public init(settings: ScreenShareSettings = .init()) {
        self.settings = settings
        let events = AsyncStream<ScreenShareCaptureEvent>.makeStream(bufferingPolicy: .bufferingNewest(100))
        self.events = events.stream
        eventContinuation = events.continuation
        let preview = AsyncStream<VoiceVideoFrame>.makeStream(bufferingPolicy: .bufferingNewest(1))
        previewFrames = preview.stream
        previewContinuation = preview.continuation
        let encoded = AsyncStream<ScreenShareEncodedVideoFrame>.makeStream(
            bufferingPolicy: .bufferingNewest(Wire.maximumOutstandingVideoFrames)
        )
        encodedFrames = encoded.stream
        encodedContinuation = encoded.continuation
        let encodedAudio = AsyncStream<CapturedOpusFrame>.makeStream(bufferingPolicy: .bufferingNewest(3))
        encodedAudioFrames = encodedAudio.stream
        encodedAudioContinuation = encodedAudio.continuation
        super.init()
    }

    deinit {
        listener?.cancel()
        channel?.close()
        eventContinuation.finish()
        previewContinuation.finish()
        encodedContinuation.finish()
        encodedAudioContinuation.finish()
    }

    public var currentVideoFormat: ScreenShareVideoFormat? { lock.withLock { format } }
    public var includesAudio: Bool { lock.withLock { settings.includesAudio } }

    public func preparePreview() async throws {
        guard Self.broadcastExtensionIdentifier != nil else {
            throw ScreenShareCaptureError.broadcastExtensionMissing
        }
        try startListening()
        eventContinuation.yield(.stateChanged(.starting))
        await showPicker()
    }

    public func presentSourcePicker() async {
        do {
            try startListening()
        } catch {
            eventContinuation.yield(.error(error.localizedDescription))
            return
        }
        await showPicker()
    }

    public func updateSettings(_ settings: ScreenShareSettings) async throws {
        lock.withLock {
            let previous = self.settings
            self.settings = settings
            guard let sourceSize else { return }
            format = Self.format(source: sourceSize, settings: settings)
            if previous.frameRate != settings.frameRate || previous.quality != settings.quality {
                generation &+= 1
            }
        }
        pushConfiguration()
    }

    public func beginEncoding() async throws -> ScreenShareVideoFormat {
        let format = lock.withLock { () -> ScreenShareVideoFormat? in
            guard let format else { return nil }
            isEncoding = true
            hasNetworkDemand = true
            generation &+= 1
            return format
        }
        guard let format else { throw ScreenShareCaptureError.outputUnavailable }
        pushConfiguration()
        eventContinuation.yield(.stateChanged(.sharing))
        return format
    }

    public func endEncoding() async {
        let stopped = lock.withLock { () -> Bool in
            isEncoding = false
            hasNetworkDemand = false
            generation &+= 1
            return isStopped
        }
        pushConfiguration()
        if !stopped { eventContinuation.yield(.stateChanged(.previewing)) }
    }

    public func setPreviewEnabled(_ enabled: Bool) {
        let changed = lock.withLock { () -> Bool in
            defer { isPreviewEnabled = enabled }
            return isPreviewEnabled != enabled
        }
        if changed { pushConfiguration() }
    }

    public func setNetworkDemand(_ demanded: Bool) throws {
        let changed = lock.withLock { () -> Bool in
            guard isEncoding, hasNetworkDemand != demanded else { return false }
            hasNetworkDemand = demanded
            generation &+= 1
            return true
        }
        if changed { pushConfiguration() }
    }

    public func stop() async {
        let current = lock.withLock { () -> (NWListener?, ScreenShareBroadcastChannel?)? in
            guard !isStopped else { return nil }
            isStopped = true
            isEncoding = false
            defer {
                listener = nil
                channel = nil
                format = nil
            }
            return (listener, channel)
        }
        guard let current else { return }
        current.0?.cancel()
        if let channel = current.1 {
            channel.send(.stop) { [channel] in channel.close() }
        }
        await MainActor.run {
            pickerView?.removeFromSuperview()
            pickerView = nil
        }
        previewContinuation.finish()
        encodedContinuation.finish()
        encodedAudioContinuation.finish()
        eventContinuation.finish()
    }

    func requestKeyframe() {
        lock.withLock { channel }?.send(.keyframe)
    }

    func isCurrentVideoFrame(generation: UInt64) -> Bool {
        lock.withLock { generation == self.generation }
    }

    func didFinishSendingVideoFrame(generation: UInt64) {
        guard let channel = lock.withLock({ generation == self.generation ? channel : nil }) else { return }
        acknowledge(generation, on: channel)
    }

    private func acknowledge(_ generation: UInt64, on channel: ScreenShareBroadcastChannel) {
        var payload = Data(capacity: 8)
        payload.appendWireInteger(generation)
        channel.send(.acknowledge, payload)
    }

    private func startListening() throws {
        let alreadyListening = lock.withLock { listener != nil || channel != nil }
        guard !alreadyListening else { return }
        let tcp = NWProtocolTCP.Options()
        tcp.noDelay = true
        let parameters = NWParameters(tls: nil, tcp: tcp)
        parameters.requiredLocalEndpoint = .hostPort(
            host: .ipv4(.loopback),
            port: NWEndpoint.Port(rawValue: Wire.port)!
        )
        parameters.allowLocalEndpointReuse = true
        let listener = try NWListener(using: parameters)
        listener.newConnectionHandler = { [weak self] connection in
            self?.accept(connection)
        }
        listener.stateUpdateHandler = { [weak self] state in
            if case .failed(let error) = state {
                self?.eventContinuation.yield(.error(error.localizedDescription))
            }
        }
        lock.withLock { self.listener = listener }
        listener.start(queue: queue)
    }

    private func accept(_ connection: NWConnection) {
        let channel = ScreenShareBroadcastChannel(connection: connection, queue: queue)
        channel.onMessage = { [weak self, weak channel] kind, payload in
            guard let self, let channel else { return }
            self.handle(kind, payload, from: channel)
        }
        channel.onClose = { [weak self, weak channel] in
            guard let self, let channel else { return }
            self.channelClosed(channel)
        }
        // Retained until a hello claims the session or the connection closes.
        lock.withLock { pendingChannels.append(channel) }
        channel.start()
    }

    private func channelClosed(_ channel: ScreenShareBroadcastChannel) {
        let shouldReport = lock.withLock { () -> Bool in
            pendingChannels.removeAll { $0 === channel }
            guard self.channel === channel else { return false }
            self.channel = nil
            sourceSize = nil
            format = nil
            return !isStopped
        }
        if shouldReport { eventContinuation.yield(.stateChanged(.stopped)) }
    }

    private func handle(_ kind: Wire.Kind, _ payload: Data, from channel: ScreenShareBroadcastChannel) {
        if kind == .hello {
            handleHello(payload, from: channel)
            return
        }
        guard lock.withLock({ self.channel === channel }) else { return }
        switch kind {
        case .video:
            guard let flags: UInt8 = payload.bigEndian(at: 0),
                  let timestamp: UInt32 = payload.bigEndian(at: 1),
                  let frameGeneration: UInt64 = payload.bigEndian(at: 5)
            else { return }
            let frame = EncodedVideoFrame(data: Data(payload.dropFirst(13)), rtpTimestamp: timestamp, isKeyframe: flags != 0)
            let result = encodedContinuation.yield(
                ScreenShareEncodedVideoFrame(frame: frame, encoderGeneration: frameGeneration)
            )
            if case .dropped(let dropped) = result, isCurrentVideoFrame(generation: dropped.encoderGeneration) {
                acknowledge(dropped.encoderGeneration, on: channel)
                channel.send(.keyframe)
            }
        case .audio:
            guard let flags: UInt8 = payload.bigEndian(at: 0),
                  let offset: UInt64 = payload.bigEndian(at: 1)
            else { return }
            encodedAudioContinuation.yield(CapturedOpusFrame(
                data: Data(payload.dropFirst(9)),
                containsVoice: flags & 1 != 0,
                sampleOffset: offset,
                containsMicrophoneVoice: flags & 2 != 0,
                containsInjectedAudio: flags & 4 != 0
            ))
        case .preview:
            guard lock.withLock({ isPreviewEnabled }),
                  let source = CGImageSourceCreateWithData(payload as CFData, nil),
                  let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
            else { return }
            previewContinuation.yield(VoiceVideoFrame(image: image))
        default:
            break
        }
    }

    private func handleHello(_ payload: Data, from channel: ScreenShareBroadcastChannel) {
        guard let hello = try? JSONDecoder().decode(Wire.Hello.self, from: payload),
              hello.magic == Wire.magic, hello.width > 0, hello.height > 0
        else {
            channel.close()
            return
        }
        let result = lock.withLock { () -> (accepted: Bool, first: Bool, listener: NWListener?) in
            guard !isStopped, self.channel == nil || self.channel === channel else { return (false, false, nil) }
            let first = self.channel == nil
            self.channel = channel
            let source = CGSize(width: hello.width, height: hello.height)
            sourceSize = source
            format = Self.format(source: source, settings: settings)
            if isEncoding { generation &+= 1 }
            let current = first ? listener : nil
            if first { listener = nil }
            return (true, first, current)
        }
        guard result.accepted else {
            channel.close()
            return
        }
        // One broadcast at a time: stop accepting once the extension has claimed the session.
        result.listener?.cancel()
        lock.withLock { pendingChannels.removeAll { $0 === channel } }
        pushConfiguration()
        eventContinuation.yield(.sourceChanged("iPad Screen"))
        if result.first { eventContinuation.yield(.stateChanged(.previewing)) }
    }

    private func pushConfiguration() {
        let current = lock.withLock { () -> (ScreenShareBroadcastChannel, Wire.Configure)? in
            guard let channel, let format else { return nil }
            return (channel, Wire.Configure(
                generation: generation,
                isEncoding: isEncoding && hasNetworkDemand,
                width: format.width,
                height: format.height,
                frameRate: format.frameRate,
                bitrate: format.bitrate,
                includesAudio: settings.includesAudio,
                isPreviewEnabled: isPreviewEnabled
            ))
        }
        guard let current, let payload = try? JSONEncoder().encode(current.1) else { return }
        current.0.send(.configure, payload)
    }

    @MainActor
    private func showPicker() {
        guard let identifier = Self.broadcastExtensionIdentifier,
              let window = UIApplication.shared.connectedScenes
              .compactMap({ $0 as? UIWindowScene })
              .flatMap(\.windows)
              .first(where: \.isKeyWindow)
        else {
            eventContinuation.yield(.error(ScreenShareCaptureError.broadcastExtensionMissing.localizedDescription))
            return
        }
        pickerView?.removeFromSuperview()
        let picker = RPSystemBroadcastPickerView(
            frame: CGRect(x: window.bounds.midX - 22, y: window.bounds.midY - 22, width: 44, height: 44)
        )
        picker.preferredExtension = identifier
        picker.showsMicrophoneButton = false
        picker.alpha = 0.01
        window.addSubview(picker)
        pickerView = picker
        picker.layoutIfNeeded()
        guard let button = picker.subviews.lazy.compactMap({ $0 as? UIButton }).first else {
            eventContinuation.yield(.error("iPadOS did not provide the screen broadcast picker."))
            return
        }
        button.sendActions(for: .touchUpInside)
    }

    /// Looked up at run time because re-signing tools rewrite bundle identifiers.
    private static var broadcastExtensionIdentifier: String? {
        guard let directory = Bundle.main.builtInPlugInsURL,
              let items = try? FileManager.default.contentsOfDirectory(
                  at: directory,
                  includingPropertiesForKeys: nil
              )
        else { return nil }
        return items.lazy
            .filter { $0.pathExtension == "appex" }
            .compactMap { Bundle(url: $0) }
            .first { bundle in
                (bundle.object(forInfoDictionaryKey: "NSExtension") as? [String: Any])?["NSExtensionPointIdentifier"]
                    as? String == "com.apple.broadcast-services-upload"
            }?
            .bundleIdentifier
    }

    private static func format(source: CGSize, settings: ScreenShareSettings) -> ScreenShareVideoFormat {
        // "720p" means the short edge here so portrait and landscape share a quality.
        // Source is capped because the extension must stay inside iPadOS's 50 MB limit.
        let target = Double(min(settings.quality.targetHeight ?? 1_440, 1_440))
        let scale = min(1, target / Double(min(source.width, source.height)))
        func even(_ value: CGFloat) -> Int {
            let rounded = Int((Double(value) * scale).rounded())
            return max(2, rounded - rounded % 2)
        }
        let width = even(source.width)
        let height = even(source.height)
        let frameRate = settings.frameRate.rawValue
        return ScreenShareVideoFormat(
            width: width,
            height: height,
            frameRate: frameRate,
            bitrate: min(9_000_000, max(2_500_000, Int(Double(width * height * frameRate) * 0.12))),
            quality: settings.quality
        )
    }
}

// MARK: - Extension side

/// Runs inside the Broadcast Upload extension.
public final class ScreenShareBroadcastUplink: @unchecked Sendable {
    private typealias Wire = ScreenShareBroadcastWire

    private let finish: @Sendable (String) -> Void
    private let queue = DispatchQueue(label: "dev.sakuracord.screen-share.uplink", qos: .userInteractive)
    private let context = CIContext(options: [.cacheIntermediates: false])
    private let busyLock = NSLock()
    private var isRendering = false

    // Everything below is confined to `queue`.
    private var channel: ScreenShareBroadcastChannel?
    private var isConnected = false
    private var hasEnded = false
    private var connectTimeout: DispatchWorkItem?
    private var idleTimer: DispatchSourceTimer?
    private var configuration: Wire.Configure?
    private var encoder: H264VideoEncoder?
    private var opus: OpusSampleBufferEncoder?
    private var outstandingFrames = 0
    private var pool: CVPixelBufferPool?
    private var poolSize = CGSize.zero
    private var lastFrame: CVPixelBuffer?
    private var lastEncodeTime: CFTimeInterval = 0
    private var lastPreviewTime: CFTimeInterval = 0
    private var announcedSize = CGSize.zero

    public init(finish: @escaping @Sendable (String) -> Void) {
        self.finish = finish
    }

    public func start() {
        queue.async { [self] in
            let tcp = NWProtocolTCP.Options()
            tcp.noDelay = true
            let connection = NWConnection(
                host: .ipv4(.loopback),
                port: NWEndpoint.Port(rawValue: Wire.port)!,
                using: NWParameters(tls: nil, tcp: tcp)
            )
            let channel = ScreenShareBroadcastChannel(connection: connection, queue: queue)
            channel.onReady = { [weak self] in self?.didConnect() }
            channel.onMessage = { [weak self] kind, payload in self?.handle(kind, payload) }
            channel.onClose = { [weak self] in self?.end("SakuraCord stopped receiving the screen share.") }
            self.channel = channel
            channel.start()

            let timeout = DispatchWorkItem { [weak self] in
                self?.end("Open SakuraCord and choose Share Screen to start broadcasting.")
            }
            connectTimeout = timeout
            queue.asyncAfter(deadline: .now() + 6, execute: timeout)

            let timer = DispatchSource.makeTimerSource(queue: queue)
            timer.schedule(deadline: .now() + 0.5, repeating: 0.5)
            timer.setEventHandler { [weak self] in self?.encodeIdleFrame() }
            timer.resume()
            idleTimer = timer
        }
    }

    public func stop() {
        queue.async { [self] in
            hasEnded = true
            teardown()
        }
    }

    public func processVideo(_ sampleBuffer: CMSampleBuffer) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let rawOrientation = CMGetAttachment(
            sampleBuffer,
            key: RPVideoSampleOrientationKey as CFString,
            attachmentModeOut: nil
        ) as? NSNumber
        let orientation = rawOrientation.flatMap { CGImagePropertyOrientation(rawValue: $0.uint32Value) } ?? .up
        let time = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        let claimed = busyLock.withLock { () -> Bool in
            defer { isRendering = true }
            return !isRendering
        }
        guard claimed else { return }
        nonisolated(unsafe) let buffer = pixelBuffer
        queue.async { [self] in
            handleFrame(buffer, orientation: orientation, time: time)
            busyLock.withLock { isRendering = false }
        }
    }

    public func processAudio(_ sampleBuffer: CMSampleBuffer) {
        nonisolated(unsafe) let sample = sampleBuffer
        queue.async { [self] in
            guard let opus, let configuration, configuration.isEncoding, configuration.includesAudio else { return }
            if let swapped = Self.nativeEndianBuffer(from: sample) {
                opus.process(swapped)
            } else {
                opus.process(sample)
            }
        }
    }

    private func didConnect() {
        connectTimeout?.cancel()
        connectTimeout = nil
        isConnected = true
    }

    private func handle(_ kind: Wire.Kind, _ payload: Data) {
        switch kind {
        case .configure:
            if let configuration = try? JSONDecoder().decode(Wire.Configure.self, from: payload) {
                apply(configuration)
            }
        case .keyframe:
            encoder?.requestKeyframe()
            if outstandingFrames < Wire.maximumOutstandingVideoFrames, let lastFrame {
                encode(lastFrame, at: CMClockGetTime(CMClockGetHostTimeClock()))
            }
        case .acknowledge:
            if let generation: UInt64 = payload.bigEndian(at: 0), generation == configuration?.generation {
                outstandingFrames = max(0, outstandingFrames - 1)
            }
        case .stop:
            end("Screen sharing was stopped in SakuraCord.")
        default:
            break
        }
    }

    private func apply(_ new: Wire.Configure) {
        let previous = configuration
        configuration = new
        if new.isEncoding, new.includesAudio {
            if opus == nil, let created = try? OpusSampleBufferEncoder(activityThreshold: 0.000_1) {
                created.handler = { [weak self] frame in
                    guard let self else { return }
                    queue.async { self.sendAudio(frame) }
                }
                opus = created
            }
        } else {
            opus?.reset()
        }
        var comparable = previous
        comparable?.includesAudio = new.includesAudio
        comparable?.isPreviewEnabled = new.isPreviewEnabled
        guard comparable != new else { return }
        outstandingFrames = 0
        encoder?.finish()
        encoder = nil
        if previous?.width != new.width || previous?.height != new.height { lastFrame = nil }
        guard new.isEncoding else { return }
        let generation = new.generation
        do {
            encoder = try H264VideoEncoder(
                width: new.width,
                height: new.height,
                framerate: new.frameRate,
                bitrate: new.bitrate,
                didDropFrame: { [weak self] in
                    guard let self else { return }
                    queue.async {
                        guard generation == self.configuration?.generation else { return }
                        self.outstandingFrames = max(0, self.outstandingFrames - 1)
                        self.encoder?.requestKeyframe()
                    }
                },
                output: { [weak self] frame in
                    guard let self else { return }
                    queue.async { self.sendVideo(frame, generation: generation) }
                }
            )
        } catch {
            end("The screen-share encoder could not start.")
            return
        }
        if let lastFrame { encode(lastFrame, at: CMClockGetTime(CMClockGetHostTimeClock())) }
    }

    private func handleFrame(_ pixelBuffer: CVPixelBuffer, orientation: CGImagePropertyOrientation, time: CMTime) {
        guard isConnected, !hasEnded, let channel else { return }
        var size = CGSize(width: CVPixelBufferGetWidth(pixelBuffer), height: CVPixelBufferGetHeight(pixelBuffer))
        if orientation.swapsAxes { size = CGSize(width: size.height, height: size.width) }
        if size != announcedSize {
            announcedSize = size
            lastFrame = nil
            let hello = Wire.Hello(magic: Wire.magic, width: Int(size.width), height: Int(size.height))
            if let payload = try? JSONEncoder().encode(hello) { channel.send(.hello, payload) }
        }
        // After a rotation, wait for the app's reply before encoding the new shape.
        guard let configuration, (configuration.width >= configuration.height) == (size.width >= size.height) else {
            return
        }
        let now = CACurrentMediaTime()
        let wantsVideo = encoder != nil
            && outstandingFrames < Wire.maximumOutstandingVideoFrames
            && now - lastEncodeTime >= 0.9 / Double(max(1, configuration.frameRate))
        let wantsPreview = configuration.isPreviewEnabled && now - lastPreviewTime >= 0.25
        guard wantsVideo || wantsPreview else { return }
        autoreleasepool {
            let image = Self.upright(pixelBuffer, orientation: orientation)
            if wantsVideo, let rendered = render(image, width: configuration.width, height: configuration.height) {
                lastFrame = rendered
                encode(rendered, at: time)
            }
            if wantsPreview {
                lastPreviewTime = now
                sendPreview(image)
            }
        }
    }

    private static func upright(_ pixelBuffer: CVPixelBuffer, orientation: CGImagePropertyOrientation) -> CIImage {
        let image = CIImage(cvPixelBuffer: pixelBuffer).oriented(orientation)
        return image.transformed(by: CGAffineTransform(translationX: -image.extent.minX, y: -image.extent.minY))
    }

    private func render(_ image: CIImage, width: Int, height: Int) -> CVPixelBuffer? {
        let size = CGSize(width: width, height: height)
        if pool == nil || poolSize != size {
            let attributes: [CFString: Any] = [
                kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange,
                kCVPixelBufferWidthKey: width,
                kCVPixelBufferHeightKey: height,
                kCVPixelBufferIOSurfacePropertiesKey: [String: Any](),
            ]
            var created: CVPixelBufferPool?
            CVPixelBufferPoolCreate(nil, nil, attributes as CFDictionary, &created)
            pool = created
            poolSize = size
        }
        guard let pool else { return nil }
        var buffer: CVPixelBuffer?
        CVPixelBufferPoolCreatePixelBuffer(nil, pool, &buffer)
        guard let buffer else { return nil }
        let scaled = image.transformed(by: CGAffineTransform(
            scaleX: size.width / image.extent.width,
            y: size.height / image.extent.height
        ))
        context.render(
            scaled,
            to: buffer,
            bounds: CGRect(origin: .zero, size: size),
            colorSpace: CGColorSpace(name: CGColorSpace.sRGB)
        )
        return buffer
    }

    private func encode(_ buffer: CVPixelBuffer, at time: CMTime) {
        guard let encoder else { return }
        outstandingFrames += 1
        lastEncodeTime = CACurrentMediaTime()
        encoder.encode(pixelBuffer: buffer, presentationTime: time)
    }

    /// ReplayKit delivers nothing while the screen is still, so a viewer joining a
    /// static screen would otherwise wait indefinitely for a picture.
    private func encodeIdleFrame() {
        guard encoder != nil, let lastFrame,
              outstandingFrames < Wire.maximumOutstandingVideoFrames,
              CACurrentMediaTime() - lastEncodeTime >= 1
        else { return }
        encode(lastFrame, at: CMClockGetTime(CMClockGetHostTimeClock()))
    }

    private func sendVideo(_ frame: EncodedVideoFrame, generation: UInt64) {
        guard generation == configuration?.generation else { return }
        var payload = Data(capacity: frame.data.count + 13)
        payload.append(frame.isKeyframe ? 1 : 0)
        payload.appendWireInteger(frame.rtpTimestamp)
        payload.appendWireInteger(generation)
        payload.append(frame.data)
        channel?.send(.video, payload)
    }

    private func sendAudio(_ frame: CapturedOpusFrame) {
        var payload = Data(capacity: frame.data.count + 9)
        var flags: UInt8 = 0
        if frame.containsVoice { flags |= 1 }
        if frame.containsMicrophoneVoice { flags |= 2 }
        if frame.containsInjectedAudio { flags |= 4 }
        payload.append(flags)
        payload.appendWireInteger(frame.sampleOffset)
        payload.append(frame.data)
        channel?.send(.audio, payload)
    }

    private func sendPreview(_ image: CIImage) {
        let scale = min(1, 640 / max(1, image.extent.width))
        let small = image.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let data = context.jpegRepresentation(
                  of: small,
                  colorSpace: colorSpace,
                  options: [CIImageRepresentationOption(rawValue: kCGImageDestinationLossyCompressionQuality as String): 0.6]
              )
        else { return }
        channel?.send(.preview, data)
    }

    /// ReplayKit's app audio can be big-endian 16-bit, which AVAudioPCMBuffer cannot describe.
    private static func nativeEndianBuffer(from sampleBuffer: CMSampleBuffer) -> AVAudioPCMBuffer? {
        guard let description = CMSampleBufferGetFormatDescription(sampleBuffer),
              let stream = CMAudioFormatDescriptionGetStreamBasicDescription(description)?.pointee,
              stream.mFormatFlags & kAudioFormatFlagIsBigEndian != 0,
              stream.mBitsPerChannel == 16,
              let format = AVAudioFormat(
                  commonFormat: .pcmFormatInt16,
                  sampleRate: stream.mSampleRate,
                  channels: stream.mChannelsPerFrame,
                  interleaved: true
              )
        else { return nil }
        let frames = AVAudioFrameCount(CMSampleBufferGetNumSamples(sampleBuffer))
        guard frames > 0, let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames) else { return nil }
        buffer.frameLength = frames
        guard CMSampleBufferCopyPCMDataIntoAudioBufferList(
            sampleBuffer,
            at: 0,
            frameCount: Int32(frames),
            into: buffer.mutableAudioBufferList
        ) == noErr else { return nil }
        let list = UnsafeMutableAudioBufferListPointer(buffer.mutableAudioBufferList)
        for audioBuffer in list {
            guard let samples = audioBuffer.mData?.assumingMemoryBound(to: UInt16.self) else { continue }
            for index in 0 ..< Int(audioBuffer.mDataByteSize) / 2 {
                samples[index] = samples[index].byteSwapped
            }
        }
        return buffer
    }

    private func end(_ message: String) {
        guard !hasEnded else { return }
        hasEnded = true
        teardown()
        finish(message)
    }

    private func teardown() {
        connectTimeout?.cancel()
        connectTimeout = nil
        idleTimer?.cancel()
        idleTimer = nil
        encoder?.finish()
        encoder = nil
        opus?.handler = nil
        opus = nil
        lastFrame = nil
        pool = nil
        channel?.onClose = nil
        channel?.close()
        channel = nil
    }
}

private extension CGImagePropertyOrientation {
    var swapsAxes: Bool {
        switch self {
        case .left, .right, .leftMirrored, .rightMirrored: true
        default: false
        }
    }
}
#endif
