// SwiftUI's AppKit integration points, expressed through its UIKit equivalents.

@MainActor
public protocol NSViewRepresentable: UIViewRepresentable where UIViewType == NSViewType {
    associatedtype NSViewType: UIView
    associatedtype UIViewType = NSViewType
    associatedtype Coordinator = Void
    func makeNSView(context: Context) -> NSViewType
    func updateNSView(_ nsView: NSViewType, context: Context)
    static func dismantleNSView(_ nsView: NSViewType, coordinator: Coordinator)
    func sizeThatFits(_ proposal: ProposedViewSize, nsView: NSViewType, context: Context) -> CGSize?
}

public extension NSViewRepresentable {
    func makeUIView(context: Context) -> NSViewType { makeNSView(context: context) }
    func updateUIView(_ uiView: NSViewType, context: Context) { updateNSView(uiView, context: context) }
    static func dismantleUIView(_ uiView: NSViewType, coordinator: Coordinator) {
        dismantleNSView(uiView, coordinator: coordinator)
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: NSViewType, context: Context) -> CGSize? {
        sizeThatFits(proposal, nsView: uiView, context: context)
    }

    static func dismantleNSView(_: NSViewType, coordinator _: Coordinator) {}
    func sizeThatFits(_: ProposedViewSize, nsView _: NSViewType, context _: Context) -> CGSize? { nil }
}

public typealias NSViewRepresentableContext = UIViewRepresentableContext
public typealias NSHostingController = UIHostingController

open class NSHostingView<Content: View>: _UIHostingView<Content> {
    public var sizingOptions: NSHostingSizingOptions {
        get { [] }
        set {}
    }

    public var safeAreaRegions: SafeAreaRegions {
        get { .all }
        set {}
    }
}

public nonisolated struct NSHostingSizingOptions: OptionSet, Sendable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }
    public static let minSize = Self(rawValue: 1)
    public static let intrinsicContentSize = Self(rawValue: 2)
    public static let maxSize = Self(rawValue: 4)
    public static let standardBounds = Self(rawValue: 7)
}

public extension Image {
    init(nsImage: UIImage) { self.init(uiImage: nsImage) }
}

public extension View {
    /// The Escape key, which is what `onExitCommand` means on macOS.
    func onExitCommand(perform action: (() -> Void)?) -> some View {
        onKeyPress(.escape) {
            guard let action else { return .ignored }
            action()
            return .handled
        }
    }

    func pointerStyle(_: NSPointerStyle?) -> some View { self }
}

public struct NSPointerStyle: Sendable {
    public static let `default` = NSPointerStyle()
    public static let link = NSPointerStyle()
    public static let horizontalText = NSPointerStyle()
    public static let columnResize = NSPointerStyle()
    public static let rowResize = NSPointerStyle()
    public static let grabIdle = NSPointerStyle()
    public static let grabActive = NSPointerStyle()
}

/// macOS opens a Settings scene; iPadOS presents the same content in a sheet.
public struct NSOpenSettingsAction: Sendable {
    public static let notification = Notification.Name("SakuraCordOpenSettings")
    public init() {}
    @MainActor public func callAsFunction() {
        NotificationCenter.default.post(name: Self.notification, object: nil)
    }
}

public extension EnvironmentValues {
    var nsOpenSettings: NSOpenSettingsAction { NSOpenSettingsAction() }
}
