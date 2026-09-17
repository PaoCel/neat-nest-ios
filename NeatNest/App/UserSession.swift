import Foundation
import FirebaseAuth
import FirebaseFirestore
import GoogleSignIn

class UserSession: ObservableObject {
    @Published var familyId: String? = nil
    @Published var currentUserName: String = ""
    @Published var currentUserGender: String = ""
    @Published var isLoggedIn: Bool = false
    @Published var pendingProfile: PendingUserProfile? = nil
    @Published var sessionErrorMessage: String? = nil

    private var usersCollection: CollectionReference = Firestore.firestore().collection("users")
    private var authStateListenerHandle: AuthStateDidChangeListenerHandle?

    var currentUserId: String? {
        Auth.auth().currentUser?.uid
    }

    deinit {
        if let authStateListenerHandle {
            Auth.auth().removeStateDidChangeListener(authStateListenerHandle)
        }
    }

    func startAuthStateListener() {
        guard authStateListenerHandle == nil else { return }

        authStateListenerHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self else { return }

            if user == nil {
                self.resetSessionState()
            } else {
                self.checkUserSession()
            }
        }
    }

    func checkUserSession() {
        guard let currentUser = Auth.auth().currentUser else {
            print("Debug: Nessun utente autenticato.")
            resetSessionState()
            return
        }

        let userId = currentUser.uid
        let userRef = usersCollection.document(userId)
        userRef.getDocument { snapshot, error in
            if let error {
                DispatchQueue.main.async {
                    self.currentUserName = ""
                    self.currentUserGender = ""
                    self.familyId = nil
                    self.pendingProfile = PendingUserProfile(user: currentUser)
                    self.sessionErrorMessage = "Accesso riuscito, ma non riesco a leggere il profilo: \(error.localizedDescription)"
                    self.isLoggedIn = false
                }
                print("Debug: Errore nel caricamento profilo utente: \(error.localizedDescription)")
                return
            }

            let userData = snapshot?.data()

            if let userName = userData?["userName"] as? String,
               let gender = userData?["gender"] as? String,
               let familyId = userData?["familyId"] as? String {
                DispatchQueue.main.async {
                    self.currentUserName = userName
                    self.currentUserGender = gender
                    self.familyId = familyId
                    self.pendingProfile = nil
                    self.sessionErrorMessage = nil
                    self.isLoggedIn = true
                }
                print("Debug: Dati utente trovati nel database: \(userData ?? [:])")
            } else {
                DispatchQueue.main.async {
                    self.currentUserName = ""
                    self.currentUserGender = ""
                    self.familyId = nil
                    self.pendingProfile = PendingUserProfile(user: currentUser, storedData: userData)
                    self.sessionErrorMessage = nil
                    self.isLoggedIn = false
                }
                print("Debug: Profilo utente incompleto, serve completare onboarding.")
            }
        }
    }

    func logout() {
        do {
            try Auth.auth().signOut()
            GIDSignIn.sharedInstance.signOut()
            DispatchQueue.main.async {
                self.pendingProfile = nil
                self.sessionErrorMessage = nil
                self.isLoggedIn = false
                self.currentUserName = ""
                self.currentUserGender = ""
                self.familyId = nil
            }
            print("Debug: Logout eseguito con successo.")
        } catch {
            print("Errore durante il logout: \(error.localizedDescription)")
        }
    }

    private func resetSessionState() {
        DispatchQueue.main.async {
            self.pendingProfile = nil
            self.sessionErrorMessage = nil
            self.isLoggedIn = false
            self.currentUserName = ""
            self.currentUserGender = ""
            self.familyId = nil
        }
    }
}
