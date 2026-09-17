import SwiftUI
import FirebaseAuth

struct RegistrationView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var userSession: UserSession

    private let previewSeed: RegistrationPreviewSeed?

    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var showPassword = false
    @State private var selectedGender = "Maschio"
    @State private var userName = ""
    @State private var errorMessage: String?
    @State private var familyCode = ""
    @State private var familyCodeExists: Bool?
    @State private var isRegistering = false
    @State private var isLoadingSuggestedFamilyCode = false
    @State private var hasAttemptedSubmit = false

    private var normalizedEmail: String {
        AuthSupport.normalizeEmail(email)
    }

    private var normalizedFamilyCode: String {
        UserProfileManager.normalizeFamilyCode(familyCode)
    }

    private var trimmedUserName: String {
        AuthSupport.trim(userName)
    }

    private var isEmailInvalid: Bool {
        hasAttemptedSubmit && !AuthSupport.isValidEmail(email)
    }

    private var isUserNameInvalid: Bool {
        hasAttemptedSubmit && trimmedUserName.isEmpty
    }

    private var isPasswordInvalid: Bool {
        hasAttemptedSubmit && password.count < 6
    }

    private var isConfirmPasswordInvalid: Bool {
        hasAttemptedSubmit && password != confirmPassword
    }

    private var isFamilyCodeInvalid: Bool {
        hasAttemptedSubmit && !UserProfileManager.isValidFamilyCode(normalizedFamilyCode)
    }

    private var passwordChecks: [PasswordCheck] {
        AuthSupport.passwordChecks(for: password, confirmPassword: confirmPassword)
    }

    private var familySummary: FamilyCodeSummary {
        AuthSupport.familyCodeSummary(for: normalizedFamilyCode, exists: familyCodeExists)
    }

    private var registerButtonEnabled: Bool {
        !isRegistering
        && !trimmedUserName.isEmpty
        && AuthSupport.isValidEmail(email)
        && password.count >= 6
        && password == confirmPassword
        && UserProfileManager.isValidFamilyCode(normalizedFamilyCode)
    }

    init(previewSeed: RegistrationPreviewSeed? = nil) {
        self.previewSeed = previewSeed
        _email = State(initialValue: previewSeed?.email ?? "")
        _password = State(initialValue: previewSeed?.password ?? "")
        _confirmPassword = State(initialValue: previewSeed?.confirmPassword ?? "")
        _selectedGender = State(initialValue: previewSeed?.selectedGender ?? "Maschio")
        _userName = State(initialValue: previewSeed?.userName ?? "")
        _errorMessage = State(initialValue: previewSeed?.errorMessage)
        _familyCode = State(initialValue: previewSeed?.familyCode ?? "")
        _familyCodeExists = State(initialValue: previewSeed?.familyCodeExists)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AuthBackgroundView()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {
                        AuthHeroCard(
                            iconName: "person.badge.plus.fill",
                            eyebrow: "Nuovo account",
                            title: "Crea il tuo spazio",
                            subtitle: "Ti guidiamo noi: account, nucleo familiare e accesso pronto in meno di un minuto.",
                            tint: Color(red: 0.16, green: 0.47, blue: 0.75),
                            trailingBadge: "1 min"
                        )

                        AuthCard {
                            AuthSectionHeader(
                                title: "I tuoi dati",
                                subtitle: "Queste informazioni servono solo a farti entrare senza frizioni."
                            )

                            AuthFieldCard(
                                title: "Nome utente",
                                iconName: "person.fill",
                                helper: "Il nome che vedranno gli altri membri della casa.",
                                isInvalid: isUserNameInvalid
                            ) {
                                TextField("Come vuoi farti chiamare?", text: $userName)
                                    .textInputAutocapitalization(.words)
                                    .autocorrectionDisabled()
                            }

                            AuthFieldCard(
                                title: "Email",
                                iconName: "envelope.fill",
                                helper: "La userai per accedere e recuperare l'account.",
                                isInvalid: isEmailInvalid
                            ) {
                                TextField("nome@esempio.it", text: $email)
                                    .keyboardType(.emailAddress)
                                    .textContentType(.emailAddress)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                            }

                            AuthFieldCard(
                                title: "Password",
                                iconName: "lock.fill",
                                helper: "Scegline una semplice da ricordare ma sicura.",
                                isInvalid: isPasswordInvalid || isConfirmPasswordInvalid
                            ) {
                                VStack(spacing: 12) {
                                    passwordInput("Crea una password", text: $password)
                                    passwordInput("Ripeti la password", text: $confirmPassword)
                                    PasswordChecklistView(checks: passwordChecks)
                                }
                            }

                            VStack(alignment: .leading, spacing: 10) {
                                Text("Genere")
                                    .font(.subheadline.weight(.semibold))

                                Picker("Genere", selection: $selectedGender) {
                                    Text("Maschio").tag("Maschio")
                                    Text("Femmina").tag("Femmina")
                                }
                                .pickerStyle(.segmented)
                            }
                        }

                        AuthCard {
                            AuthSectionHeader(
                                title: "Nucleo familiare",
                                subtitle: "Se il codice esiste entri in quella casa. Se non esiste la creiamo noi."
                            )

                            AuthFieldCard(
                                title: "Codice famiglia",
                                iconName: "house.fill",
                                helper: "Formato richiesto: 4 lettere e 4 numeri.",
                                isInvalid: isFamilyCodeInvalid
                            ) {
                                TextField("CASA1234", text: $familyCode)
                                    .textInputAutocapitalization(.characters)
                                    .autocorrectionDisabled()
                                    .font(.system(.body, design: .monospaced))
                                    .onChange(of: familyCode) { newValue in
                                        let normalized = UserProfileManager.normalizeFamilyCode(newValue)
                                        if normalized != newValue {
                                            familyCode = normalized
                                            return
                                        }

                                        checkFamilyCode()
                                    }
                            }

                            if isLoadingSuggestedFamilyCode {
                                ProgressView("Sto preparando un codice per te...")
                                    .tint(.green)
                            }

                            HStack(spacing: 10) {
                                Button {
                                    loadSuggestedFamilyCode(force: true)
                                } label: {
                                    AuthSecondaryButton(
                                        title: familyCode.isEmpty ? "Genera per me" : "Rigenera",
                                        systemImage: "wand.and.stars",
                                        tint: .green
                                    )
                                }
                                .buttonStyle(.plain)
                                .disabled(isLoadingSuggestedFamilyCode)
                            }

                            AuthBanner(
                                title: familySummary.title,
                                message: familySummary.message,
                                systemImage: familySummary.systemImage,
                                tint: color(for: familySummary.tintName)
                            )
                        }

                        if let errorMessage {
                            AuthBanner(
                                title: "Registrazione non completata",
                                message: errorMessage,
                                systemImage: "exclamationmark.octagon.fill",
                                tint: .red
                            )
                        }

                        AuthCard {
                            AuthSectionHeader(
                                title: "Hai gia un account?",
                                subtitle: "Sei solo nel posto sbagliato: puoi tornare all'accesso senza perdere nulla."
                            )

                            Button("Torna al login") {
                                dismiss()
                            }
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.blue)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 24)
                    .padding(.bottom, 120)
                }
            }
            .preferredColorScheme(.light)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Chiudi") {
                        dismiss()
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button(action: registerUser) {
                    AuthPrimaryButton(
                        title: "Crea account",
                        systemImage: "checkmark.circle.fill",
                        colors: [Color(red: 0.16, green: 0.47, blue: 0.75), Color(red: 0.29, green: 0.63, blue: 0.88)],
                        isLoading: isRegistering,
                        isEnabled: registerButtonEnabled
                    )
                }
                .buttonStyle(.plain)
                .disabled(!registerButtonEnabled)
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 10)
                .background(.thinMaterial)
            }
            .onAppear {
                if previewSeed == nil, familyCode.isEmpty {
                    loadSuggestedFamilyCode(force: true)
                }
            }
        }
    }

    private func registerUser() {
        hasAttemptedSubmit = true
        errorMessage = nil
        userSession.sessionErrorMessage = nil

        guard !trimmedUserName.isEmpty else {
            errorMessage = "Scegli un nome utente per continuare."
            return
        }

        guard AuthSupport.isValidEmail(email) else {
            errorMessage = "Inserisci un'email valida."
            return
        }

        guard password.count >= 6 else {
            errorMessage = "La password deve avere almeno 6 caratteri."
            return
        }

        guard password == confirmPassword else {
            errorMessage = "Le password non coincidono."
            return
        }

        guard UserProfileManager.isValidFamilyCode(normalizedFamilyCode) else {
            errorMessage = "Il codice famiglia deve avere 4 lettere e 4 numeri."
            return
        }

        isRegistering = true
        checkFamilyCodeAndRegister()
    }

    private func checkFamilyCodeAndRegister() {
        UserProfileManager.checkFamilyCodeExists(normalizedFamilyCode) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    completeRegistration(familyCode: normalizedFamilyCode)
                case .failure(let error):
                    isRegistering = false
                    errorMessage = "Non riesco a verificare il nucleo familiare: \(error.localizedDescription)"
                }
            }
        }
    }

    private func completeRegistration(familyCode: String) {
        Auth.auth().createUser(withEmail: normalizedEmail, password: password) { result, error in
            if let error {
                DispatchQueue.main.async {
                    self.isRegistering = false
                    self.errorMessage = AuthSupport.friendlyMessage(for: error)
                }
                return
            }

            guard let user = result?.user else {
                DispatchQueue.main.async {
                    self.isRegistering = false
                    self.errorMessage = "Non riesco a completare la registrazione adesso."
                }
                return
            }

            let profileChangeRequest = user.createProfileChangeRequest()
            profileChangeRequest.displayName = trimmedUserName
            profileChangeRequest.commitChanges { _ in
                UserProfileManager.completeProfile(
                    userId: user.uid,
                    email: normalizedEmail,
                    userName: trimmedUserName,
                    gender: selectedGender,
                    familyCode: familyCode
                ) { result in
                    DispatchQueue.main.async {
                        switch result {
                        case .success:
                            completeRegistrationFlow()
                        case .failure(let error):
                            self.isRegistering = false
                            self.errorMessage = "Errore durante il salvataggio del profilo: \(error.localizedDescription)"
                        }
                    }
                }
            }
        }
    }

    private func completeRegistrationFlow() {
        isRegistering = false
        errorMessage = nil
        userSession.checkUserSession()
        dismiss()
    }

    private func checkFamilyCode() {
        if let previewSeed {
            familyCodeExists = previewSeed.familyCodeExists ?? false
            return
        }

        guard !normalizedFamilyCode.isEmpty else {
            familyCodeExists = nil
            return
        }

        guard UserProfileManager.isValidFamilyCode(normalizedFamilyCode) else {
            familyCodeExists = nil
            return
        }

        UserProfileManager.checkFamilyCodeExists(normalizedFamilyCode) { result in
            DispatchQueue.main.async {
                switch result {
                case .failure(let error):
                    self.errorMessage = "Non riesco a verificare il nucleo familiare: \(error.localizedDescription)"
                    self.familyCodeExists = nil
                case .success(let exists):
                    self.familyCodeExists = exists
                }
            }
        }
    }

    private func loadSuggestedFamilyCode(force: Bool) {
        guard force || familyCode.isEmpty else { return }
        guard !isLoadingSuggestedFamilyCode else { return }

        if let previewSeed {
            familyCode = previewSeed.familyCode
            familyCodeExists = previewSeed.familyCodeExists ?? false
            isLoadingSuggestedFamilyCode = false
            return
        }

        isLoadingSuggestedFamilyCode = true
        UserProfileManager.suggestAvailableFamilyCode { result in
            DispatchQueue.main.async {
                self.isLoadingSuggestedFamilyCode = false

                switch result {
                case .success(let suggestion):
                    self.familyCode = suggestion
                    self.familyCodeExists = false
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func passwordInput(_ placeholder: String, text: Binding<String>) -> some View {
        HStack(spacing: 12) {
            Group {
                if showPassword {
                    TextField(placeholder, text: text)
                } else {
                    SecureField(placeholder, text: text)
                }
            }
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()

            Button {
                showPassword.toggle()
            } label: {
                Image(systemName: showPassword ? "eye.slash" : "eye")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .background(Color(uiColor: .tertiarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func color(for tintName: String) -> Color {
        switch tintName {
        case "blue":
            return .blue
        case "green":
            return .green
        default:
            return .secondary
        }
    }
}

@MainActor
private struct RegistrationViewPreviewContainer: View {
    private let session = PreviewSupport.makeUserSession(isLoggedIn: false)

    var body: some View {
        RegistrationView(previewSeed: PreviewSupport.registrationSeed)
            .environmentObject(session)
    }
}

#Preview("Registrazione") {
    RegistrationViewPreviewContainer()
}
