import SwiftUI

struct TaskCardView: View {
    var task: Task
    var currentUserName: String
    @State private var showTaskPreview = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(task.title)
                .font(.headline)
                .foregroundColor(.black)
                .lineLimit(3)
                .truncationMode(.tail)
                .fixedSize(horizontal: false, vertical: true)
            Text("Creato da: \(task.createdBy)")
                .font(.subheadline)
                .foregroundColor(.gray)
            Text("Incaricato: \(task.assignedTo)")
                .font(.subheadline)
                .foregroundColor(.blue)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .shadow(radius: 4)
        .onTapGesture {
            showTaskPreview = true
        }
        .sheet(isPresented: $showTaskPreview) {
            TaskPreviewView(task: task, onDeleteTask: {
                deleteTask(task: task)
            })
        }
    }

    func deleteTask(task: Task) {
        print("Eliminazione del task: \(task.title)")
    }
}

struct CheckBoxView: View {
    @State private var isChecked: Bool
    var action: () -> Void

    init(isChecked: Bool, action: @escaping () -> Void) {
        _isChecked = State(initialValue: isChecked)
        self.action = action
    }

    var body: some View {
        Button(action: {
            withAnimation {
                isChecked.toggle()
                action()
            }
        }) {
            Image(systemName: isChecked ? "checkmark.square.fill" : "square")
                .resizable()
                .frame(width: 24, height: 24)
                .foregroundColor(isChecked ? .green : .gray)
        }
        .buttonStyle(PlainButtonStyle())
    }
}
