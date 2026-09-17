import SwiftUI
import FirebaseAuth
import FirebaseCore
import LocalAuthentication
import KeychainAccess
import AuthenticationServices
import GoogleSignIn
import UIKit

struct LoginView: View {
    @EnvironmentObject var userSession: UserSession

    @State private var email = ""
    @State private var password = ""
    @State private var showPassword = false
    @State private var errorMessage: String?
    @State private var showRegistrationView = false
    @State private var rememberThisDevice = false
    @State private var isAuthenticating = false
    @State private var currentNonce: String?

    @AppStorage("shouldUseBiometrics") private var shouldUseBiometrics = false

    private let keychain = Keychain(service: Bundle.main.bundleIdentifier ?? "com.ios.NeatNest")

    private var normalizedEmail: String {
        AuthSupport.normalizeEmail(email)
    }

    private var hasSavedCredentials: Bool {
        guard let savedEmail = UserDefaults.standard.string(forKey: "lastUsedEmail") else { return false }
        return (try? keychain.get(savedEmail)) != nil
    }

    private var canSubmit: Bool {
        !normalizedEmail.isEmpty && !AuthSupport.trim(password).isEmpty && !isAuthenticating
    }

    private var biometricButtonTitle: String {
        let context = LAContext()
        var authError: NSError?
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &authError)

        switch context.biometryType {
        case .touchID:
            return "Accedi con Touch ID"
        default:
            return "Accedi con Face ID"
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AuthBackgroundView()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {
                        AuthHeroCard(
                            iconName: "house.and.flag.fill",
                            eyebrow: "NeatNest",
                            title: "Bentornato",
                            subtitle: "Accedi in pochi secondi e riprendi casa, budget e Smart Grocery da dove avevi lasciato.",
                            tint: Color(red: 0.18, green: 0.55, blue: 0.44),
                            trailingBadge: "Accesso"
                        )

                        if hasSavedCredentials {
                            Button(action: authenticateWithFaceID) {
                                AuthSecondaryButton(
                                    title: biometricButtonTitle,
                                    systemImage: "faceid",
                                    tint: .green
                                )
                            }
                            .buttonStyle(.plain)
                        }

                        AuthCard {
                            AuthSectionHeader(
                                title: "Accedi come preferisci",
                                subtitle: "Apple e Google sono il modo piu rapido. In alternativa puoi usare email e password."
                            )

                            VStack(spacing: 12) {
                                Button(action: signInWithGoogle) {
                                    AuthSocialButton(
                                        title: "Continua con Google",
                                        systemImage: "globe",
                                        tint: .blue
                                    )
                                }
                                .buttonStyle(.plain)
                                .disabled(isAuthenticating)

                                SignInWithAppleButton(.signIn, onRequest: configureAppleSignInRequest, onCompletion: handleAppleSignIn)
                                    .signInWithAppleButtonStyle(.black)
                                    .frame(height: 54)
                                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                                    .disabled(isAuthenticating)
                            }

                            HStack(spacing: 12) {
                                Rectangle()
                                    .fill(Color.secondary.opacity(0.18))
                                    .frame(height: 1)
                                Text("oppure usa email")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                Rectangle()
                                    .fill(Color.secondary.opacity(0.18))
                                    .frame(height: 1)
                            }

                            AuthFieldCard(
                                title: "Email",
                                iconName: "envelope.fill",
                                helper: "Usa la stessa email con cui hai creato l'account."
                            ) {
                                TextField("nome@esempio.it", text: $email)
                                    .keyboardType(.emailAddress)
                                    .textContentType(.username)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                            }

                            AuthFieldCard(
                                title: "Password",
                                iconName: "lock.fill",
                                helper: "Se attivi il promemoria salveremo l'accesso su questo iPhone."
                            ) {
                                HStack(spacing: 12) {
                                    Group {
                                        if showPassword {
                                            TextField("La tua password", text: $password)
                                        } else {
                                            SecureField("La tua password", text: $password)
                                        }
                                    }
                                    .textContentType(.password)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                    .submitLabel(.go)
                                    .onSubmit(loginUser)

                                    Button {
                                        showPassword.toggle()
                                    } label: {
                                        Image(systemName: showPassword ? "eye.slash" : "eye")
                                            .foregroundStyle(.secondary)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }

                            Toggle(isOn: $rememberThisDevice) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Ricorda questo iPhone")
                                        .font(.subheadline.weight(.semibold))
                                    Text("Cosi potrai rientrare piu velocemente con Face ID.")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .toggleStyle(.switch)
                        }

                        if let errorMessage {
                            AuthBanner(
                                title: "C'e qualcosa da sistemare",
                                message: errorMessage,
                                systemImage: "exclamationmark.triangle.fill",
                                tint: .red
                            )
                        }

                        if let sessionErrorMessage = userSession.sessionErrorMessage {
                            AuthBanner(
                                title: "Accesso riuscito, profilo da completare",
                                message: sessionErrorMessage,
                                systemImage: "person.crop.circle.badge.exclamationmark",
                                tint: .orange
                            )
                        }

                        Button(action: loginUser) {
                            AuthPrimaryButton(
                                title: "Accedi",
                                systemImage: "arrow.right.circle.fill",
                                colors: [Color(red: 0.18, green: 0.55, blue: 0.44), Color(red: 0.29, green: 0.66, blue: 0.53)],
                                isLoading: isAuthenticating,
                                isEnabled: canSubmit
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(!canSubmit)

                        AuthCard {
                            AuthSectionHeader(
                                title: "Nuovo su NeatNest?",
                                subtitle: "Creiamo l'account, ti suggeriamo un codice famiglia e sei dentro in meno di un minuto."
                            )

                            Button {
                                showRegistrationView = true
                            } label: {
                                AuthSecondaryButton(
                                    title: "Crea un account",
                                    systemImage: "person.badge.plus",
                                    tint: .green
                                )
                            }
                            .buttonStyle(.plain)
                            .disabled(isAuthenticating)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 28)
                    .padding(.bottom, 32)
                }
            }
            .navigationBarHidden(true)
            .preferredColorScheme(.light)
            .sheet(isPresented: $showRegistrationView) {
                RegistrationView()
                    .environmentObject(userSession)
                    .presentationDragIndicator(.visible)
            }
            .onAppear {
                rememberThisDevice = shouldUseBiometrics
                checkSavedCredentials()
            }
        }
    }

    private func checkSavedCredentials() {
        if shouldUseBiometrics, hasSavedCredentials {
            authenticateWithFaceID()
        }
    }

    private func saveCredentials() {
        UserDefaults.standard.set(normalizedEmail, forKey: "lastUsedEmail")
        try? keychain.set(password, key: normalizedEmail)
        shouldUseBiometrics = true
    }

    private func clearSavedCredentials() {
        if let savedEmail = UserDefaults.standard.string(forKey: "lastUsedEmail") {
            try? keychain.remove(savedEmail)
        }
        UserDefaults.standard.removeObject(forKey: "lastUsedEmail")
        shouldUseBiometrics = false
    }

    private func loginUser() {
        guard !normalizedEmail.isEmpty && !AuthSupport.trim(password).isEmpty else {
            errorMessage = "Inserisci email e password per continuare."
            return
        }

        errorMessage = nil
        userSession.sessionErrorMessage = nil
        isAuthenticating = true

        Auth.auth().signIn(withEmail: normalizedEmail, password: password) { result, error in
            DispatchQueue.main.async {
                self.isAuthenticating = false

                if let error {
                    self.errorMessage = AuthSupport.friendlyMessage(for: error)
                    return
                }

                guard result?.user.uid != nil else {
                    self.errorMessage = "Non riesco a completare l'accesso adesso."
                    return
                }

                if rememberThisDevice {
                    saveCredentials()
                } else {
                    clearSavedCredentials()
                }

                self.errorMessage = nil
                self.userSession.checkUserSession()
            }
        }
    }

    private func authenticateWithFaceID() {
        let context = LAContext()
        context.localizedCancelTitle = "Annulla"
        var authError: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &authError) else {
            errorMessage = "Face ID o Touch ID non sono disponibili su questo dispositivo."
            return
        }

        let reason = "Accedi piu velocemente a NeatNest"
        context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, error in
            if let laError = error as? LAError, laError.code == .userCancel {
                DispatchQueue.main.async {
                    self.errorMessage = nil
                }
                return
            }

            DispatchQueue.main.async {
                if success,
                   let savedEmail = UserDefaults.standard.string(forKey: "lastUsedEmail"),
                   let savedPassword = try? keychain.get(savedEmail) {
                    self.email = savedEmail
                    self.password = savedPassword
                    self.rememberThisDevice = true
                    self.shouldUseBiometrics = true
                    self.loginUser()
                } else if let error {
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func signInWithGoogle() {
        errorMessage = nil
        userSession.sessionErrorMessage = nil
        isAuthenticating = true

        guard let clientID = FirebaseApp.app()?.options.clientID else {
            errorMessage = "Configurazione Google non trovata."
            isAuthenticating = false
            return
        }

        guard let presentingViewController = UIApplication.shared.topViewController else {
            errorMessage = "Non riesco ad aprire il login Google in questo momento."
            isAuthenticating = false
            return
        }

        let configuration = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = configuration

        GIDSignIn.sharedInstance.signIn(withPresenting: presentingViewController) { result, error in
            if let error {
                DispatchQueue.main.async {
                    self.isAuthenticating = false
                    self.errorMessage = AuthSupport.friendlyMessage(for: error)
                }
                return
            }

            guard let user = result?.user,
                  let idToken = user.idToken?.tokenString else {
                DispatchQueue.main.async {
                    self.isAuthenticating = false
                    self.errorMessage = "Non sono riuscito a recuperare il token Google."
                }
                return
            }

            let credential = GoogleAuthProvider.credential(
                withIDToken: idToken,
                accessToken: user.accessToken.tokenString
            )

            signInWithFirebaseCredential(credential)
        }
    }

    private func configureAppleSignInRequest(_ request: ASAuthorizationAppleIDRequest) {
        let nonce = randomNonceString()
        currentNonce = nonce
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)
        errorMessage = nil
        userSession.sessionErrorMessage = nil
    }

    private func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .failure(let error):
            errorMessage = AuthSupport.friendlyMessage(for: error)
            isAuthenticating = false
        case .success(let authorization):
            guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                errorMessage = "Le credenziali Apple non sono valide."
                isAuthenticating = false
                return
            }

            guard let nonce = currentNonce else {
                errorMessage = "Manca un passaggio di sicurezza Apple. Riprova."
                isAuthenticating = false
                return
            }

            guard let appleIDToken = appleIDCredential.identityToken,
                  let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
                errorMessage = "Non sono riuscito a leggere il token Apple."
                isAuthenticating = false
                return
            }

            isAuthenticating = true
            let credential = OAuthProvider.appleCredential(
                withIDToken: idTokenString,
                rawNonce: nonce,
                fullName: appleIDCredential.fullName
            )

            signInWithFirebaseCredential(credential)
        }
    }

    private func signInWithFirebaseCredential(_ credential: AuthCredential) {
        Auth.auth().signIn(with: credential) { _, error in
            DispatchQueue.main.async {
                self.isAuthenticating = false

                if let error {
                    self.errorMessage = AuthSupport.friendlyMessage(for: error)
                    return
                }

                self.errorMessage = nil
                self.userSession.checkUserSession()
            }
        }
    }
}

@MainActor
private struct LoginViewPreviewContainer: View {
    private let session = PreviewSupport.makeUserSession(
        isLoggedIn: false,
        sessionErrorMessage: "Accesso riuscito, ma per questa anteprima il profilo e mostrato come da completare."
    )

    var body: some View {
        LoginView()
            .environmentObject(session)
    }
}

#Preview("Login") {
    LoginViewPreviewContainer()
}
