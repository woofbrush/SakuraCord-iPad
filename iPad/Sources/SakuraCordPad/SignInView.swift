import CoreImage.CIFilterBuiltins
import DiscordProtocol
import HCaptcha
import SwiftUI
import UIKit

struct PadRootView: View {
    @Environment(PadSession.self) private var session
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            switch session.phase {
            case .restoring, .connecting:
                ProgressView("Connecting to Discord…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .signedOut:
                SignInView()
            case .ready:
                WorkspaceView(session: session)
            }
        }
        .task { await session.restore() }
        .onChange(of: scenePhase, initial: true) { _, phase in
            session.setActive(phase == .active)
        }
    }
}

private enum CaptchaPurpose {
    case password, remoteAuth
}

struct SignInView: View {
    @Environment(PadSession.self) private var session
    @State private var email = ""
    @State private var password = ""
    @State private var mfa: DiscordMFAChallenge?
    @State private var mfaMethod: DiscordMFAMethod = .totp
    @State private var mfaCode = ""
    @State private var captcha: (challenge: DiscordCaptchaChallenge, purpose: CaptchaPurpose)?
    @State private var isWorking = false
    @State private var error: String?
    @State private var remoteAuth = DiscordRemoteAuthManager()
    @State private var qrURL: URL?
    @State private var qrStatus = "Preparing a QR code…"
    @FocusState private var focusedField: Field?

    private enum Field { case email, password, code }

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                VStack(spacing: 6) {
                    Text("Welcome to SakuraCord").font(.largeTitle.bold())
                    Text("Sign in with your Discord account.").foregroundStyle(.secondary)
                }
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 40) { credentialsForm; qrPanel }
                    VStack(spacing: 32) { credentialsForm; qrPanel }
                }
                if let message = error ?? session.errorMessage {
                    Text(message).foregroundStyle(.red).multilineTextAlignment(.center)
                }
                if session.hasSavedAccount {
                    Button("Try Saved Account Again") { Task { await session.restore() } }
                }
            }
            .padding(40)
            .frame(maxWidth: 860)
            .frame(maxWidth: .infinity)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .task { await runRemoteAuth() }
        .onDisappear { Task { await remoteAuth.disconnect() } }
        .sheet(isPresented: Binding(get: { captcha != nil }, set: { if !$0 { cancelCaptcha() } })) {
            if let captcha {
                CaptchaSheet(challenge: captcha.challenge) { token in
                    Task { await solveCaptcha(captcha, token: token) }
                }
            }
        }
    }

    private var credentialsForm: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let mfa {
                Text("Two-factor authentication").font(.title2.bold())
                Picker("Method", selection: $mfaMethod) {
                    ForEach(mfa.methods, id: \.self) { method in
                        Text(method.label).tag(method)
                    }
                }
                .pickerStyle(.segmented)
                TextField(mfaMethod == .backup ? "Backup code" : "6-digit code", text: $mfaCode)
                    .textContentType(.oneTimeCode)
                    .keyboardType(mfaMethod == .backup ? .asciiCapable : .numberPad)
                    .focused($focusedField, equals: .code)
                    .onSubmit { Task { await submitMFA(mfa) } }
                    .textFieldStyle(.roundedBorder)
                HStack {
                    Button("Back") { self.mfa = nil; mfaCode = "" }
                    if mfaMethod == .sms {
                        Button("Send Code") { Task { try? await session.authenticator.sendSMS(for: mfa) } }
                    }
                    Spacer()
                    Button("Verify") { Task { await submitMFA(mfa) } }
                        .buttonStyle(.borderedProminent)
                        .keyboardShortcut(.defaultAction)
                        .disabled(isWorking || mfaCode.isEmpty)
                }
            } else {
                Text("Email or phone").font(.headline)
                TextField("name@example.com", text: $email)
                    .textContentType(.username)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: .email)
                    .onSubmit { focusedField = .password }
                    .textFieldStyle(.roundedBorder)
                Text("Password").font(.headline)
                SecureField("Password", text: $password)
                    .textContentType(.password)
                    .focused($focusedField, equals: .password)
                    .onSubmit { Task { await submitPassword() } }
                    .textFieldStyle(.roundedBorder)
                Button {
                    Task { await submitPassword() }
                } label: {
                    Text("Log In").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
                .disabled(isWorking || email.isEmpty || password.isEmpty)
            }
            if isWorking { ProgressView().frame(maxWidth: .infinity) }
        }
        .frame(width: 380)
        .onAppear { focusedField = .email }
    }

    private var qrPanel: some View {
        VStack(spacing: 14) {
            Group {
                if let qrURL, let image = QRCode.image(for: qrURL.absoluteString) {
                    Image(uiImage: image).interpolation(.none).resizable()
                } else {
                    ProgressView()
                }
            }
            .frame(width: 200, height: 200)
            .padding(12)
            .background(.white, in: RoundedRectangle(cornerRadius: 16))
            Text("Log in with QR code").font(.title3.bold())
            Text(qrStatus)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(width: 240)
            Button("New Code") { Task { await remoteAuth.restart() } }
                .buttonStyle(.bordered)
        }
    }

    // MARK: Password sign-in

    private func submitPassword() async {
        guard !isWorking else { return }
        isWorking = true
        defer { isWorking = false }
        error = nil
        do {
            try await handle(session.authenticator.login(identifier: email, password: password))
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func submitMFA(_ challenge: DiscordMFAChallenge) async {
        guard !isWorking else { return }
        isWorking = true
        defer { isWorking = false }
        do {
            let credential = try await session.authenticator.completeMFA(
                challenge: challenge, method: mfaMethod, code: mfaCode
            )
            await session.connect(credential)
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func handle(_ step: DiscordNativeAuthenticationStep) async {
        switch step {
        case .authenticated(let credential):
            password = ""
            await session.connect(credential)
        case .mfa(let challenge):
            mfa = challenge
            mfaMethod = challenge.methods.first ?? .totp
            focusedField = .code
        case .captcha(let challenge):
            captcha = (challenge, .password)
        }
    }

    // MARK: QR sign-in

    private func runRemoteAuth() async {
        let events = await remoteAuth.events()
        await remoteAuth.connect()
        for await event in events {
            switch event {
            case .connecting:
                qrURL = nil
                qrStatus = "Preparing a QR code…"
            case .qrCode(let url):
                qrURL = url
                qrStatus = "Scan this with the Discord mobile app to sign in instantly."
            case .scanned(let user):
                qrStatus = "Check your phone\(user.map { ", \($0.username)" } ?? "") — confirm the sign-in there."
            case .pendingLogin(let ticket):
                qrStatus = "Signing in…"
                await exchange(ticket: ticket)
            case .cancelled:
                qrStatus = "Sign-in was cancelled on your phone."
                await remoteAuth.restart()
            case .failed(let message):
                qrStatus = message
            }
        }
    }

    private func exchange(ticket: String) async {
        do {
            switch try await session.authenticator.exchangeRemoteAuthTicket(ticket) {
            case .encryptedToken(let encrypted):
                try await acceptRemoteAuth(encrypted)
            case .captcha(let challenge):
                captcha = (challenge, .remoteAuth)
            }
        } catch {
            qrStatus = error.localizedDescription
        }
    }

    private func acceptRemoteAuth(_ encrypted: String) async throws {
        let token = try await remoteAuth.decryptToken(encrypted)
        let credential = try await session.authenticator.acceptRemoteAuthToken(token)
        await remoteAuth.disconnect()
        await session.connect(credential)
    }

    // MARK: Captcha

    private func solveCaptcha(
        _ captcha: (challenge: DiscordCaptchaChallenge, purpose: CaptchaPurpose),
        token: String?
    ) async {
        self.captcha = nil
        guard let token else {
            await session.authenticator.cancelCaptcha(challengeID: captcha.challenge.id)
            error = "The Discord challenge was not completed."
            return
        }
        do {
            switch captcha.purpose {
            case .password:
                try await handle(session.authenticator.completeCaptcha(
                    challenge: captcha.challenge, solutionToken: token
                ))
            case .remoteAuth:
                try await acceptRemoteAuth(session.authenticator.completeRemoteAuthCaptcha(
                    challenge: captcha.challenge, solutionToken: token
                ))
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func cancelCaptcha() {
        guard let challenge = captcha?.challenge else { return }
        captcha = nil
        Task { await session.authenticator.cancelCaptcha(challengeID: challenge.id) }
    }
}

private extension DiscordMFAMethod {
    var label: LocalizedStringKey {
        switch self {
        case .totp: "Authenticator"
        case .backup: "Backup Code"
        case .sms: "SMS"
        }
    }
}

private enum QRCode {
    static func image(for string: String) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage?.transformed(by: CGAffineTransform(scaleX: 8, y: 8)),
              let cgImage = CIContext().createCGImage(output, from: output.extent)
        else { return nil }
        return UIImage(cgImage: cgImage)
    }
}

/// Hosts Discord's hCaptcha challenge, which both sign-in paths may require.
private struct CaptchaSheet: View {
    let challenge: DiscordCaptchaChallenge
    let completion: (String?) -> Void

    var body: some View {
        NavigationStack {
            CaptchaHost(challenge: challenge, completion: completion)
                .navigationTitle("Verify you’re human")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { completion(nil) }
                    }
                }
        }
        .presentationSizing(.form)
    }
}

private struct CaptchaHost: UIViewRepresentable {
    let challenge: DiscordCaptchaChallenge
    let completion: (String?) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(completion: completion) }

    func makeUIView(context: Context) -> UIView {
        let host = UIView()
        context.coordinator.start(challenge, on: host)
        return host
    }

    func updateUIView(_ uiView: UIView, context: Context) {}

    static func dismantleUIView(_ uiView: UIView, coordinator: Coordinator) {
        coordinator.hcaptcha?.stop()
    }

    final class Coordinator {
        let completion: (String?) -> Void
        var hcaptcha: HCaptcha?
        private var finished = false

        init(completion: @escaping (String?) -> Void) {
            self.completion = completion
        }

        func start(_ challenge: DiscordCaptchaChallenge, on host: UIView) {
            hcaptcha = try? HCaptcha(
                apiKey: challenge.siteKey,
                baseURL: URL(string: "https://discord.com"),
                size: challenge.shouldServeInvisible ? .invisible : .normal,
                rqdata: challenge.rqdata,
                theme: "dark",
                diagnosticLog: false
            )
            guard let hcaptcha else { return finish(nil) }
            hcaptcha.configureWebView { webView in
                webView.frame = host.bounds
                webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
                webView.isOpaque = false
                webView.backgroundColor = .clear
                host.addSubview(webView)
            }
            hcaptcha.validate(on: host, resetOnError: false) { [weak self] result in
                let token = try? result.dematerialize()
                Task { @MainActor in self?.finish(token) }
            }
        }

        private func finish(_ token: String?) {
            guard !finished else { return }
            finished = true
            completion(token)
        }
    }
}
