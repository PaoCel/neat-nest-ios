import Foundation
import FirebaseAuth

enum AuthSupport {
    static func trim(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func normalizeEmail(_ value: String) -> String {
        trim(value).lowercased()
    }

    static func isValidEmail(_ value: String) -> Bool {
        let normalized = normalizeEmail(value)
        guard !normalized.isEmpty else { return false }
        return normalized.range(
            of: #"^[A-Z0-9._%+\-]+@[A-Z0-9.\-]+\.[A-Z]{2,}$"#,
            options: [.regularExpression, .caseInsensitive]
        ) != nil
    }

    static func friendlyMessage(for error: Error) -> String {
        let nsError = error as NSError

        guard nsError.domain == AuthErrorDomain,
              let code = AuthErrorCode(rawValue: nsError.code) else {
            return error.localizedDescription
        }

        switch code {
        case .wrongPassword, .invalidCredential:
            return "Email o password non corretti. Riprova con calma."
        case .userNotFound:
            return "Non trovo un account con questa email."
        case .invalidEmail:
            return "L'indirizzo email non sembra corretto."
        case .emailAlreadyInUse:
            return "Questa email e gia collegata a un account. Puoi accedere direttamente."
        case .weakPassword:
            return "Scegli una password di almeno 6 caratteri."
        case .networkError:
            return "Sembra esserci un problema di connessione. Riprova tra un attimo."
        case .tooManyRequests:
            return "Hai fatto troppi tentativi ravvicinati. Aspetta un momento e riprova."
        case .operationNotAllowed:
            return "Questo metodo di accesso non e disponibile al momento."
        case .accountExistsWithDifferentCredential:
            return "Esiste gia un account con questa email, ma con un metodo di accesso diverso."
        default:
            return error.localizedDescription
        }
    }

    static func passwordChecks(for password: String, confirmPassword: String = "") -> [PasswordCheck] {
        [
            PasswordCheck(title: "Almeno 6 caratteri", isSatisfied: password.count >= 6),
            PasswordCheck(title: "Le password coincidono", isSatisfied: !confirmPassword.isEmpty && password == confirmPassword)
        ]
    }

    static func familyCodeSummary(for code: String, exists: Bool?) -> FamilyCodeSummary {
        if !UserProfileManager.isValidFamilyCode(code) {
            return FamilyCodeSummary(
                title: "Formato codice",
                message: "Usa 4 lettere e 4 numeri, per esempio CASA1234.",
                systemImage: "textformat.abc.dottedunderline",
                tintName: "secondary"
            )
        }

        if let exists {
            return FamilyCodeSummary(
                title: exists ? "Nucleo trovato" : "Nuovo nucleo",
                message: exists
                    ? "Con questo codice entrerai in una casa gia esistente."
                    : "Con questo codice creeremo un nuovo nucleo per iniziare subito.",
                systemImage: exists ? "person.2.fill" : "house.fill",
                tintName: exists ? "blue" : "green"
            )
        }

        return FamilyCodeSummary(
            title: "Codice pronto",
            message: "Lo puoi usare cosi oppure sostituirlo con uno tuo.",
            systemImage: "checkmark.seal.fill",
            tintName: "green"
        )
    }
}

struct PasswordCheck: Identifiable {
    let id = UUID()
    let title: String
    let isSatisfied: Bool
}

struct FamilyCodeSummary {
    let title: String
    let message: String
    let systemImage: String
    let tintName: String
}
