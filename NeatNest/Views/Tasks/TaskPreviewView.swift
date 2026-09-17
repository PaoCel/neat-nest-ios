import SwiftUI
import FirebaseDatabase

struct TaskPreviewView: View {
    var task: Task
    var onDeleteTask: () -> Void

    @EnvironmentObject var userSession: UserSession
    @Environment(\.presentationMode) var presentationMode
    @State private var showEditTaskView = false
    @State private var showingDeleteConfirmationAlert = false

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            VStack(alignment: .leading, spacing: 16) {
                Text(task.title)
                    .font(.largeTitle)
                    .foregroundColor(.black)
                    .multilineTextAlignment(.leading)
                Text("Creato da: \(task.createdBy)")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                Text("Incaricato: \(task.assignedTo)")
                    .font(.subheadline)
                    .foregroundColor(.blue)
                Text("Data di completamento: \(task.date)")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            .shadow(radius: 4)
            .frame(maxWidth: .infinity)

            Spacer()

            HStack(spacing: 20) {
                Button(action: {
                    showEditTaskView = true
                }) {
                    VStack {
                        Image(systemName: "pencil")
                            .resizable()
                            .frame(width: 24, height: 24)
                            .foregroundColor(.blue)
                        Text("Modifica")
                            .font(.subheadline)
                            .foregroundColor(.blue)
                    }
                    .padding()
                    .background(Color.white)
                    .cornerRadius(10)
                    .shadow(radius: 4)
                }
                .sheet(isPresented: $showEditTaskView) {
                    EditTaskView(
                        task: task,
                        onTaskUpdated: {
                            presentationMode.wrappedValue.dismiss()
                        },
                        onTaskDeleted: {
                            presentationMode.wrappedValue.dismiss()
                            onDeleteTask()
                        }
                    )
                    .environmentObject(userSession)
                }

                Button(action: {
                    showingDeleteConfirmationAlert = true
                }) {
                    VStack {
                        Image(systemName: "trash")
                            .resizable()
                            .frame(width: 24, height: 24)
                            .foregroundColor(.red)
                        Text("Elimina")
                            .font(.subheadline)
                            .foregroundColor(.red)
                    }
                    .padding()
                    .background(Color.white)
                    .cornerRadius(10)
                    .shadow(radius: 4)
                }
            }

            Spacer()
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(15)
        .shadow(radius: 4)
        .alert(isPresented: $showingDeleteConfirmationAlert) {
            Alert(
                title: Text("Conferma Eliminazione"),
                message: Text("Sei sicuro di voler eliminare questa faccenda?"),
                primaryButton: .destructive(Text("Elimina")) {
                    deleteTask()
                },
                secondaryButton: .cancel()
            )
        }
    }

    private func deleteTask() {
        guard let familyId = userSession.familyId, !familyId.isEmpty else { return }
        let taskRef = Database.database().reference().child("tasks").child(familyId).child(task.id)

        taskRef.removeValue { error, _ in
            if let error = error {
                print("Errore durante l'eliminazione del task: \(error.localizedDescription)")
            } else {
                print("Task eliminato con successo")
                onDeleteTask()
                presentationMode.wrappedValue.dismiss()
            }
        }
    }
}
