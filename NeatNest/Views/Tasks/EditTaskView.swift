import SwiftUI
import FirebaseDatabase

struct EditTaskView: View {
    var task: Task
    var onTaskUpdated: () -> Void
    var onTaskDeleted: () -> Void

    @EnvironmentObject var userSession: UserSession
    @State private var taskTitle: String
    @State private var assignedTo: String
    @State private var selectedDate: Date
    @State private var users: [String] = []
    @Environment(\.presentationMode) var presentationMode

    init(task: Task, onTaskUpdated: @escaping () -> Void, onTaskDeleted: @escaping () -> Void) {
        self.task = task
        self.onTaskUpdated = onTaskUpdated
        self.onTaskDeleted = onTaskDeleted
        _taskTitle = State(initialValue: task.title)
        _assignedTo = State(initialValue: task.assignedTo)
        _selectedDate = State(initialValue: Date())
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Faccenda")) {
                    TextField("Titolo della Faccenda", text: $taskTitle)
                }

                Section(header: Text("Assegna a")) {
                    if users.isEmpty {
                        Text("Nessun utente disponibile")
                            .foregroundColor(.red)
                    } else {
                        Picker("Seleziona chi", selection: $assignedTo) {
                            ForEach(users, id: \.self) { user in
                                Text(user).tag(user)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                    }
                }

                Section(header: Text("Data di Completamento")) {
                    DatePicker("Seleziona data", selection: $selectedDate, displayedComponents: .date)
                }

                Button(action: {
                    updateTask()
                    onTaskUpdated()
                    presentationMode.wrappedValue.dismiss()
                }) {
                    HStack {
                        Image(systemName: "square.and.arrow.down")
                            .resizable()
                            .frame(width: 24, height: 24)
                            .foregroundColor(.green)
                        Text("Salva Modifiche")
                            .font(.subheadline)
                            .foregroundColor(.green)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.white)
                    .cornerRadius(10)
                    .shadow(radius: 4)
                }
                .padding(.top, 20)

                Button(action: {
                    deleteTask()
                    onTaskDeleted()
                    presentationMode.wrappedValue.dismiss()
                }) {
                    HStack {
                        Image(systemName: "trash")
                            .resizable()
                            .frame(width: 24, height: 24)
                            .foregroundColor(.red)
                        Text("Elimina Faccenda")
                            .font(.subheadline)
                            .foregroundColor(.red)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.white)
                    .cornerRadius(10)
                    .shadow(radius: 4)
                }
                .padding(.top, 10)
            }
            .navigationTitle("Modifica Faccenda")
            .navigationBarItems(leading: Button("Annulla") {
                presentationMode.wrappedValue.dismiss()
            })
            .onAppear {
                fetchUsers()
            }
        }
    }

    func fetchUsers() {
        guard let familyId = userSession.familyId else {
            print("Debug: Nessun familyId trovato.")
            return
        }

        let familyUsersRef = Database.database().reference().child("families").child(familyId).child("members")
        familyUsersRef.observeSingleEvent(of: .value) { snapshot in
            var newUsers: [String] = []

            for child in snapshot.children {
                if let snapshot = child as? DataSnapshot,
                   let dict = snapshot.value as? [String: Any],
                   let username = dict["username"] as? String {
                    newUsers.append(username)
                }
            }

            DispatchQueue.main.async {
                self.users = newUsers
            }
        }
    }

    func updateTask() {
        guard let familyId = userSession.familyId else { return }

        let taskRef = Database.database().reference().child("tasks").child(familyId).child(task.id)
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: selectedDate)

        let updatedData: [String: Any] = [
            "title": taskTitle,
            "assignedTo": assignedTo,
            "date": dateString
        ]

        taskRef.updateChildValues(updatedData) { error, _ in
            if let error = error {
                print("Errore durante l'aggiornamento della faccenda: \(error.localizedDescription)")
            } else {
                print("Task aggiornato con successo")
            }
        }
    }

    func deleteTask() {
        guard let familyId = userSession.familyId else { return }

        let taskRef = Database.database().reference().child("tasks").child(familyId).child(task.id)

        taskRef.removeValue { error, _ in
            if let error = error {
                print("Errore durante l'eliminazione della faccenda: \(error.localizedDescription)")
            } else {
                print("Task eliminato con successo")
            }
        }
    }
}
