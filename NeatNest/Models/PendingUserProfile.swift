import Foundation
import FirebaseAuth

struct PendingUserProfile {
    let email: String
    let suggestedUserName: String
    let suggestedGender: String
    let suggestedFamilyCode: String

    init(user: User, storedData: [String: Any]? = nil) {
        let storedUserName = storedData?["userName"] as? String
        let storedGender = storedData?["gender"] as? String
        let storedFamilyId = storedData?["familyId"] as? String

        email = user.email ?? (storedData?["email"] as? String ?? "")
        suggestedUserName = PendingUserProfile.sanitizedUserName(
            from: storedUserName,
            fallbackDisplayName: user.displayName,
            email: email
        )
        suggestedGender = storedGender ?? "Maschio"
        suggestedFamilyCode = storedFamilyId ?? ""
    }

    private static func sanitizedUserName(from storedValue: String?, fallbackDisplayName: String?, email: String) -> String {
        let candidates = [storedValue, fallbackDisplayName]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if let firstCandidate = candidates.first {
            return firstCandidate
        }

        if let localPart = email.split(separator: "@").first {
            return String(localPart)
        }

        return ""
    }
}
