import Foundation
import FirebaseFirestore

enum UserProfileManager {
    private static var firestore: Firestore {
        Firestore.firestore()
    }

    private static var usersCollection: CollectionReference {
        firestore.collection("users")
    }

    private static var familiesCollection: CollectionReference {
        firestore.collection("families")
    }

    private static var categoriesCollection: CollectionReference {
        firestore.collection("categories")
    }

    private static let defaultBudgetCategories: [[String: Any]] = [
        ["name": "Stipendio", "type": "income", "color": "#34a853", "isActive": true],
        ["name": "Alimentari", "type": "expense", "color": "#4285f4", "isActive": true],
        ["name": "Casa", "type": "expense", "color": "#ea4335", "isActive": true],
        ["name": "Trasporti", "type": "expense", "color": "#fbbc05", "isActive": true],
        ["name": "Svago", "type": "expense", "color": "#9c27b0", "isActive": true]
    ]

    static func normalizeFamilyCode(_ familyCode: String) -> String {
        familyCode
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
    }

    static func isValidFamilyCode(_ familyCode: String) -> Bool {
        let normalized = normalizeFamilyCode(familyCode)
        return normalized.range(of: #"^[A-Z]{4}[0-9]{4}$"#, options: .regularExpression) != nil
    }

    static func checkFamilyCodeExists(_ familyCode: String, completion: @escaping (Result<Bool, Error>) -> Void) {
        let normalized = normalizeFamilyCode(familyCode)
        guard !normalized.isEmpty else {
            completion(.success(false))
            return
        }

        familiesCollection.document(normalized).getDocument { snapshot, error in
            if let error {
                completion(.failure(error))
                return
            }

            completion(.success(snapshot?.exists == true))
        }
    }

    static func suggestAvailableFamilyCode(completion: @escaping (Result<String, Error>) -> Void) {
        suggestAvailableFamilyCode(attempt: 0, completion: completion)
    }

    static func completeProfile(
        userId: String,
        email: String,
        userName: String,
        gender: String,
        familyCode: String,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        let normalizedFamilyCode = normalizeFamilyCode(familyCode)
        saveProfile(
            userId: userId,
            email: email,
            userName: userName,
            gender: gender,
            familyCode: normalizedFamilyCode,
            completion: completion
        )
    }

    static func updateUserName(
        userId: String,
        userName: String,
        familyId: String?,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        let trimmedUserName = userName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedUserName.isEmpty else {
            completion(.failure(ProfileError.invalidUserName))
            return
        }

        let userRef = usersCollection.document(userId)
        userRef.setData([
            "userName": trimmedUserName,
            "updatedAt": FieldValue.serverTimestamp()
        ], merge: true) { error in
            if let error {
                completion(.failure(error))
                return
            }

            guard let familyId = familyId, !familyId.isEmpty else {
                completion(.success(()))
                return
            }

            familiesCollection.document(familyId).setData([
                "members": [
                    userId: ["username": trimmedUserName]
                ]
            ], merge: true) { error in
                if let error {
                    completion(.failure(error))
                } else {
                    completion(.success(()))
                }
            }
        }
    }

    static func deleteUserProfile(userId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        usersCollection.document(userId).delete { error in
            if let error {
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        }
    }

    private static func saveProfile(
        userId: String,
        email: String,
        userName: String,
        gender: String,
        familyCode: String,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        let familyRef = familiesCollection.document(familyCode)

        familyRef.getDocument { snapshot, error in
            if let error {
                completion(.failure(error))
                return
            }

            let familyExists = snapshot?.exists == true
            let batch = firestore.batch()
            let userRef = usersCollection.document(userId)

            batch.setData([
                "userName": userName,
                "email": email,
                "gender": gender,
                "familyId": familyCode,
                "familyRole": "admin",
                "updatedAt": FieldValue.serverTimestamp(),
                "createdAt": FieldValue.serverTimestamp()
            ], forDocument: userRef, merge: true)

            if familyExists {
                batch.setData([
                    "members": [
                        userId: ["username": userName]
                    ]
                ], forDocument: familyRef, merge: true)
            } else {
                batch.setData([
                    "createdBy": userId,
                    "createdAt": FieldValue.serverTimestamp(),
                    "members": [
                        userId: ["username": userName]
                    ]
                ], forDocument: familyRef, merge: true)

                for category in defaultBudgetCategories {
                    var categoryData = category
                    categoryData["familyId"] = familyCode
                    categoryData["createdAt"] = FieldValue.serverTimestamp()
                    let categoryRef = categoriesCollection.document()
                    batch.setData(categoryData, forDocument: categoryRef)
                }
            }

            batch.commit { error in
                if let error {
                    completion(.failure(error))
                } else {
                    completion(.success(familyCode))
                }
            }
        }
    }

    private static func suggestAvailableFamilyCode(
        attempt: Int,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        guard attempt < 12 else {
            completion(.failure(ProfileError.unableToGenerateFamilyCode))
            return
        }

        let candidate = randomFamilyCode()
        checkFamilyCodeExists(candidate) { result in
            switch result {
            case .success(let exists):
                if exists {
                    suggestAvailableFamilyCode(attempt: attempt + 1, completion: completion)
                } else {
                    completion(.success(candidate))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    private static func randomFamilyCode() -> String {
        let letters = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ")
        let numbers = Array("0123456789")

        let letterPart = String((0..<4).compactMap { _ in letters.randomElement() })
        let numberPart = String((0..<4).compactMap { _ in numbers.randomElement() })
        return "\(letterPart)\(numberPart)"
    }

    enum ProfileError: LocalizedError {
        case invalidUserName
        case unableToGenerateFamilyCode

        var errorDescription: String? {
            switch self {
            case .invalidUserName:
                return "Il nome utente non puo essere vuoto."
            case .unableToGenerateFamilyCode:
                return "Non riesco a generare un codice famiglia disponibile."
            }
        }
    }
}
