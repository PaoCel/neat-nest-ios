import SwiftUI
import FirebaseAuth

struct CompleteProfileView: View {
    @EnvironmentObject var userSession: UserSession

    private let previewSeed: CompleteProfilePreviewSeed?

    @State private var userName = ""
    @State private var selectedGender = "Maschio"
    @State private var familyCode = ""
    @State private var familyCodeExists: Bool?
    @State private var errorMessage: String?
    @State private var isSaving = false
    @State private var isLoadingSuggestedFamilyCode = false

    private var pendingProfile: PendingUserProfile? {
        userSession.pendingProfile
    }

    private var displayEmail: String? {
        previewSeed?.email ?? pendingProfile?.email
    }

    private var normalizedFamilyCode: String {
        UserProfileManager.normalizeFamilyCode(familyCode)
    }

    private var trimmedUserName: String {
        AuthSupport.trim(userName)
    }

    private var familySummary: FamilyCodeSummary {
        AuthSupport.familyCodeSummary(for: normalizedFamilyCode, exists: familyCodeExists)
    }

    private var canContinue: Bool {
        !isSaving && !trimmedUserName.isEmpty && UserProfileManager.isValidFamilyCode(normalizedFamilyCode)
    }

    init(previewSeed: CompleteProfilePreviewSeed? = nil) {
        self.previewSeed = previewSeed
        _userName = State(initialValue: previewSeed?.userName ?? "")
        _selectedGender = State(initialValue: previewSeed?.selectedGender ?? "Maschio")
        _familyCode = State(initialValue: previewSeed?.familyCode ?? "")
        _familyCodeExists = State(initialValue: previewSeed?.familyCodeExists)
        _errorMessage = State(initialValue: previewSeed?.errorMessage)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AuthBackgroundView()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {
                        AuthHeroCard(
                            iconName: "person.crop.circle.badge.checkmark",
                            eyebrow: "Quasi fatto",
                            title: "Completa il profilo",
                            subtitle: "Il tuo accesso e gia pronto. Ci servono solo gli ultimi dettagli per entrare in NeatNest senza interruzioni.",
                            tint: Color(red: 0.22, green: 0.61, blue: 0.47),
                            trailingBadge: "Ultimo step"
                        )

                        if let email = displayEmail, !email.isEmpty {
                            AuthCard {
                                AuthSectionHeader(
                                    title: "Account collegato",
                                    subtitle: "Questo indirizzo e gia stato recuperato dal provider di accesso."
                                )

                                AuthFieldCard(
                                    title: "Email",
                                    iconName: "envelope.badge.fill",
                                    helper: "Non devi reinserirla."
                                ) {
                                    Text(email)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .foregroundStyle(.primary)
                                }
                            }
                        }

                        AuthCard {
                            AuthSectionHeader(
                                title: "Chi sei in casa",
                                subtitle: "Ti mostreremo cosi in task, budget e Smart Grocery."
                            )

                            AuthFieldCard(
                                title: "Nome utente",
                                iconName: "person.fill",
                                helper: "Puoi cambiarlo piu avanti dal profilo."
                            ) {
                                TextField("Come vuoi farti chiamare?", text: $userName)
                                    .textInputAutocapitalization(.words)
                                    .autocorrectionDisabled()
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
                                title: "Scegli la casa",
                                subtitle: "Se hai gia un codice usalo qui. Altrimenti te ne proponiamo uno pronto."
                            )

                            AuthFieldCard(
                                title: "Codice famiglia",
                                iconName: "house.fill",
                                helper: "Formato richiesto: 4 lettere e 4 numeri."
                            ) {
                                TextField("CASA1234", text: $familyCode)
                                    .font(.system(.body, design: .monospaced))
                                    .textInputAutocapitalization(.characters)
                                    .autocorrectionDisabled()
                                    .onChange(of: familyCode) { newValue in
                                        let normalized = UserProfileManager.normalizeFamilyCode(newValue)
                                        if normalized != newValue {
                                            familyCode = normalized
                                            return
                                        }

                                        updateFamilyCodeStatus()
                                    }
                            }

                            if isLoadingSuggestedFamilyCode {
                                ProgressView("Sto scegliendo un codice disponibile...")
                                    .tint(.green)
                            }

                            Button {
                                loadSuggestedFamilyCode(force: true)
                            } label: {
                                AuthSecondaryButton(
                                    title: familyCode.isEmpty ? "Suggeriscimene uno" : "Genera un altro codice",
                                    systemImage: "wand.and.stars",
                                    tint: .green
                                )
                            }
                            .buttonStyle(.plain)
                            .disabled(isLoadingSuggestedFamilyCode)

                            AuthBanner(
                                title: familySummary.title,
                                message: familySummary.message,
                                systemImage: familySummary.systemImage,
                                tint: color(for: familySummary.tintName)
                            )
                        }

                        if let errorMessage {
                            AuthBanner(
                                title: "Profilo non completo",
                                message: errorMessage,
                                systemImage: "exclamationmark.triangle.fill",
                                tint: .red
                            )
                        }

                        if let sessionErrorMessage = userSession.sessionErrorMessage {
                            AuthBanner(
                                title: "Serve un ultimo controllo",
                                message: sessionErrorMessage,
                                systemImage: "wifi.exclamationmark",
                                tint: .orange
                            )
                        }

                        Button("Esci") {
                            userSession.logout()
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 24)
                    .padding(.bottom, 120)
                }
            }
            .navigationBarHidden(true)
            .preferredColorScheme(.light)
            .safeAreaInset(edge: .bottom) {
                Button(action: saveProfile) {
                    AuthPrimaryButton(
                        title: "Continua",
                        systemImage: "arrow.right.circle.fill",
                        colors: [Color(red: 0.22, green: 0.61, blue: 0.47), Color(red: 0.33, green: 0.72, blue: 0.56)],
                        isLoading: isSaving,
                        isEnabled: canContinue
                    )
                }
                .buttonStyle(.plain)
                .disabled(!canContinue)
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 10)
                .background(.thinMaterial)
            }
            .onAppear {
                if previewSeed == nil {
                    populateInitialValues()
                }
            }
        }
    }

    private func populateInitialValues() {
        guard let pendingProfile else { return }

        if userName.isEmpty {
            userName = pendingProfile.suggestedUserName
        }

        if familyCode.isEmpty {
            if !pendingProfile.suggestedFamilyCode.isEmpty {
                familyCode = pendingProfile.suggestedFamilyCode
            } else {
                loadSuggestedFamilyCode(force: true)
            }
        }

        selectedGender = pendingProfile.suggestedGender
        updateFamilyCodeStatus()
    }

    private func updateFamilyCodeStatus() {
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
                case .success(let exists):
                    self.familyCodeExists = exists
                    self.userSession.sessionErrorMessage = nil
                case .failure(let error):
                    self.familyCodeExists = nil
                    self.userSession.sessionErrorMessage = "Non riesco a verificare il nucleo familiare: \(error.localizedDescription)"
                }
            }
        }
    }

    private func saveProfile() {
        guard let currentUser = Auth.auth().currentUser else {
            errorMessage = "Utente non autenticato."
            return
        }

        let email = currentUser.email ?? pendingProfile?.email ?? ""

        guard !trimmedUserName.isEmpty else {
            errorMessage = "Scegli un nome utente per continuare."
            return
        }

        guard !email.isEmpty else {
            errorMessage = "Email non disponibile per questo account."
            return
        }

        guard UserProfileManager.isValidFamilyCode(normalizedFamilyCode) else {
            errorMessage = "Il codice famiglia deve avere 4 lettere e 4 numeri."
            return
        }

        errorMessage = nil
        userSession.sessionErrorMessage = nil
        isSaving = true

        UserProfileManager.completeProfile(
            userId: currentUser.uid,
            email: email,
            userName: trimmedUserName,
            gender: selectedGender,
            familyCode: normalizedFamilyCode
        ) { result in
            DispatchQueue.main.async {
                self.isSaving = false

                switch result {
                case .success:
                    userSession.checkUserSession()
                case .failure(let error):
                    self.errorMessage = "Errore durante il salvataggio del profilo: \(error.localizedDescription)"
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
private struct CompleteProfileViewPreviewContainer: View {
    private let session = PreviewSupport.makeUserSession(
        isLoggedIn: false,
        sessionErrorMessage: "Simulazione anteprima: ultimo step prima di entrare nell'app."
    )

    var body: some View {
        CompleteProfileView(previewSeed: PreviewSupport.completeProfileSeed)
            .environmentObject(session)
    }
}

#Preview("Completa profilo") {
    CompleteProfileViewPreviewContainer()
}
