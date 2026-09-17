import SwiftUI
import Combine
import FirebaseDatabase

@Observable
final class AddTaskViewModel {
    var taskTitle: String = ""
    var selectedUser: String = ""
    var selectedDate: Date = Date()
    var users: [String] = []
    var isLoading: Bool = false
    var errorMessage: String? = nil

    private var ref: DatabaseReference = Database.database().reference().child("tasks")
    private var userSession: UserSession
    private var cancellables: Set<AnyCancellable> = []

    init(userSession: UserSession) {
        self.userSession = userSession
        fetchUsers()
    }

    func fetchUsers() {
        guard let familyId = userSession.familyId else {
            errorMessage = "Nessun familyId disponibile"
            return
        }

        isLoading = true
        let usersRef = Database.database().reference().child("users")
        usersRef.queryOrdered(byChild: "familyId").queryEqual(toValue: familyId).observe(.value) { [weak self] snapshot in
            guard let self = self else { return }
            var newUsers: [String] = []

            for child in snapshot.children {
                if let snapshot = child as? DataSnapshot,
                   let userData = snapshot.value as? [String: Any],
                   let userName = userData["userName"] as? String {
                    newUsers.append(userName)
                }
            }

            DispatchQueue.main.async {
                self.users = newUsers
                if self.selectedUser.isEmpty, !newUsers.isEmpty {
                    self.selectedUser = newUsers[0]
                }
                self.isLoading = false
            }
        }
    }

    func addTask(completion: @escaping (Bool) -> Void) {
        guard let familyId = userSession.familyId else {
            errorMessage = "Nessun familyId disponibile"
            completion(false)
            return
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: selectedDate)

        let taskData: [String: Any] = [
            "title": taskTitle,
            "assignedTo": selectedUser,
            "createdBy": userSession.currentUserName,
            "date": dateString,
            "isConfirmed": false
        ]

        let newTaskRef = ref.child(familyId).childByAutoId()
        newTaskRef.setValue(taskData) { [weak self] error, _ in
            if let error = error {
                self?.errorMessage = "Errore nel salvataggio del task: \(error.localizedDescription)"
                completion(false)
            } else {
                completion(true)
            }
        }
    }
}
