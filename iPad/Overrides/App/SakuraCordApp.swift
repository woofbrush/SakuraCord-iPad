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
    @State private var isShowingSettings = false
    private let appDelegate: AppDelegate

    init() {
        _ = NSApplication.shared
        ComposerPromisedFileStorage.removeAbandonedFilesAtStartup()
        SharedMediaDataLoader.removeAbandonedDownloadsAtStartup()
        DiagnosticsPreferences.restore()
        let configuration = AppLaunchConfiguration(arguments: ProcessInfo.processInfo.arguments)
        let mockProvider = configuration.mode == .offlineTesting ? MockChatProvider() : nil
        appDelegate = AppDelegate()
        let appModel = AppModel(
            launchMode: configuration.mode,
            awaitsOfflineSignIn: configuration.includesSignInFixture,
            hasSavedAccountsAtLaunch: configuration.mode == .normal
                && UserDefaultsSavedAccountStore.shared.hasSavedAccounts,
            provider: mockProvider,
            notificationService: MacNativeNotificationService(
                deliversNotifications: configuration.mode != .offlineTesting
            ),
            soundPlayer: configuration.mode == .offlineTesting ? NoopAppSoundPlayer() : MacAppSoundPlayer()
        )
        appModel.showInspector = GeneralWindowRestorationStore.shared.memberListIsVisible
        AppAppearanceController.shared.apply(appModel.appearanceSettings.colorScheme)
        InterfaceScale.shared.update(appModel.appearanceSettings.interfaceSize)
        _model = State(initialValue: appModel)
        UNUserNotificationCenter.current().delegate = appDelegate.notificationCenterDelegate
    }

    var body: some Scene {
        WindowGroup("SakuraCord", id: "main") {
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
                    isShowingSettings = true
                }
                .task {
                    appDelegate.model = model
                    await appDelegate.startSession(for: model)
                    await model.applyConfiguredLocalStorageLimit()
                }
                .onChange(of: scenePhase, initial: true) { _, phase in
                    model.reportApplicationActive(phase == .active)
                }
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
        [.sound]
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
