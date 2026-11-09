import AppKit
import DiscordProtocol
import SakuraCordModels
import SwiftUI
import UserNotifications

/// iPadOS entry point. The workspace is the macOS RootView; the Settings scene,
/// which iPadOS does not have, is presented as a sheet of the same SettingsView.
@main
struct SakuraCordApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var model: AppModel
    private let appDelegate: AppDelegate

    init() {
        _ = NSApplication.shared
        ComposerPromisedFileStorage.removeAbandonedFilesAtStartup()
        SharedMediaDataLoader.removeAbandonedDownloadsAtStartup()
        MediaViewerPreviewFile.removeAbandonedFilesAtStartup()
        DiagnosticsPreferences.restore()
        let configuration = AppLaunchConfiguration(arguments: ProcessInfo.processInfo.arguments)
        let mockProvider = configuration.mode == .offlineTesting ? MockChatProvider() : nil
        appDelegate = AppDelegate()
        let notificationPreferences = NotificationPreferences()
        let appModel = AppModel(
            launchMode: configuration.mode,
            awaitsOfflineSignIn: configuration.includesSignInFixture,
            hasSavedAccountsAtLaunch: configuration.mode == .normal
                && UserDefaultsSavedAccountStore.shared.hasSavedAccounts,
            provider: mockProvider,
            notificationService: MacNativeNotificationService(
                deliversNotifications: configuration.mode != .offlineTesting
            ),
            soundPlayer: configuration.mode == .offlineTesting
                ? NoopAppSoundPlayer() : MacAppSoundPlayer(notificationPreferences: notificationPreferences),
            notificationPreferences: notificationPreferences
        )
        appModel.inspectorVisibility = GeneralWindowRestorationStore.shared.loadInspectorVisibility()
        AppAppearanceController.shared.apply(appModel.appearanceSettings.colorScheme)
        InterfaceScale.shared.update(appModel.appearanceSettings.interfaceSize)
        FileTypeIconCache.prewarm()
        _model = State(initialValue: appModel)
        UNUserNotificationCenter.current().delegate = appDelegate.notificationCenterDelegate
        NSApp.textKeyEquivalentHandler = { [weak appModel] event in
            guard let appModel, let chord = KeyboardShortcutChord(event: event),
                  let action = KeyboardShortcutAction.allCases.first(where: {
                      KeyboardShortcutSettingsStore.shared.shortcut(for: $0) == chord
                  }),
                  appModel.keyboardShortcutActionIsEnabled(action)
            else { return false }
            appModel.performKeyboardShortcutAction(action)
            return true
        }
    }

    var body: some Scene {
        WindowGroup("SakuraCord", id: "main") {
            PadWindowRoot(primary: model, appDelegate: appDelegate)
        }
        .commands {
            SakuraCordCommands(updateController: appDelegate.updateController, model: model)
        }
    }
}

final class AppDelegate: NSObject {
    private(set) static weak var current: AppDelegate?
    let updateController = AppUpdateController()
    let notificationCenterDelegate = SakuraCordNotificationCenterDelegate()
    weak var model: AppModel?
    private var sessionStartTask: Task<Void, Never>?

    override init() {
        super.init()
        Self.current = self
    }

    func startSession(for model: AppModel) async {
        self.model = model
        if sessionStartTask == nil {
            sessionStartTask = Task { await model.start() }
        }
        await sessionStartTask?.value
    }
}

final class SakuraCordNotificationCenterDelegate: NSObject {}

extension SakuraCordNotificationCenterDelegate: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        guard let link = NotificationDeepLink(
            userInfo: response.notification.request.content.userInfo
        ) else { return }
        await MainActor.run {
            NotificationCenter.default.post(name: .sakuracordNotificationDeepLink, object: link)
        }
    }
}

/// A window of its own: each has a model, so windows can show different conversations.
private struct PadWindowRoot: View {
    let primary: AppModel
    let appDelegate: AppDelegate
    @Environment(\.scenePhase) private var scenePhase
    @State private var model: AppModel?
    @State private var window: UIWindow?
    @State private var isShowingSettings = false

    var body: some View {
        Group {
            if let model { content(model) }
        }
        .background { PadWindowProbe { window = $0 } }
        .onAppear {
            if model == nil { model = PadWindowModels.claim(primary: primary) }
        }
    }

    private func content(_ model: AppModel) -> some View {
            RootView(model: model)
                .modifier(TranslationTaskHost(coordinator: model.translation.coordinator))
                .onReceive(NotificationCenter.default.publisher(for: NSLocale.currentLocaleDidChangeNotification)) { _ in
                    model.resetAllTranslations()
                }
                .focusedSceneValue(\.shortcutCommandContext, .workspace(model))
                .windowModalInputScope()
                .sheet(isPresented: $isShowingSettings) {
                    SettingsView(model: model, updateController: appDelegate.updateController)
                        .windowModalInputScope()
                        .presentationSizing(.page)
                }
                .onReceive(NotificationCenter.default.publisher(for: NSOpenSettingsAction.notification)) { _ in
                    if window == nil || window === NSApp.keyWindow { isShowingSettings = true }
                }
                .task {
                    AppAccentColorController.shared.start()
                    _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
                    if model === primary {
                        appDelegate.model = model
                        await appDelegate.startSession(for: model)
                    } else {
                        await model.start()
                    }
                    await model.applyConfiguredLocalStorageLimit()
                }
                .onDisappear { PadWindowModels.release(model, primary: primary) }
                .onChange(of: scenePhase, initial: true) { _, phase in
                    model.reportApplicationActive(phase == .active)
                }
    }
}

/// The first window uses the app's model. Later ones sign in to a session of their own
/// and stay silent, so a message doesn't notify or ring once per window.
@MainActor
private enum PadWindowModels {
    private static var isPrimaryInUse = false

    static func claim(primary: AppModel) -> AppModel {
        guard isPrimaryInUse, primary.launchMode == .normal else {
            isPrimaryInUse = true
            return primary
        }
        let model = AppModel(
            launchMode: primary.launchMode,
            awaitsOfflineSignIn: false,
            hasSavedAccountsAtLaunch: UserDefaultsSavedAccountStore.shared.hasSavedAccounts,
            provider: nil,
            notificationService: MacNativeNotificationService(deliversNotifications: false),
            soundPlayer: NoopAppSoundPlayer(),
            notificationPreferences: NotificationPreferences()
        )
        model.inspectorVisibility = GeneralWindowRestorationStore.shared.loadInspectorVisibility()
        return model
    }

    static func release(_ model: AppModel, primary: AppModel) {
        if model === primary {
            isPrimaryInUse = false
        } else {
            let provider = model.accountSession().provider
            Task { await provider.disconnect() }
        }
    }
}

/// Reports the window, and keeps its size class regular: a compact split view shows one
/// column and takes the sidebar's state out of the app's hands.
private struct PadWindowProbe: UIViewRepresentable {
    let changed: (UIWindow?) -> Void

    func makeUIView(context _: Context) -> Probe { Probe() }
    func updateUIView(_ view: Probe, context _: Context) { view.changed = changed }

    final class Probe: UIView {
        var changed: ((UIWindow?) -> Void)?

        override func didMoveToWindow() {
            super.didMoveToWindow()
            window?.rootViewController?.traitOverrides.horizontalSizeClass = .regular
            let window = window
            Task { @MainActor [weak self] in self?.changed?(window) }
        }
    }
}
