import SwiftUI
import FirebaseDatabase
import FirebaseAuth
import UserNotifications

struct TasksView: View {
    @EnvironmentObject var userSession: UserSession
    @State private var tasksByMonth: [String: [String: [Task]]] = [:]
    @State private var showingAddTaskView = false
    @State private var expandedMonths: Set<String> = []
    @State private var showUserOverview = false
    @State private var showingDeleteConfirmationAlert = false
    @State private var taskToDelete: Task? = nil
    @State private var users: [String] = []
    @Environment(\.presentationMode) var presentationMode

    private var ref: DatabaseReference = Database.database().reference().child("tasks")
    private var usersRef: DatabaseReference = Database.database().reference().child("users")

    var body: some View {
        ZStack {
            VStack {
                taskListView
            }
            .navigationTitle("Faccende Domestiche")
            .navigationBarItems(trailing: refreshButton)
            .onAppear {
                observeTasks()
            }
            .sheet(isPresented: $showingAddTaskView) {
                AddTaskView(userSession: userSession)
                    .environmentObject(userSession)
            }
            .alert(isPresented: $showingDeleteConfirmationAlert) {
                Alert(
                    title: Text("Conferma Eliminazione"),
                    message: Text("Sei sicuro di voler eliminare questa faccenda?"),
                    primaryButton: .destructive(Text("Elimina")) {
                        if let task = taskToDelete {
                            deleteTask(task: task)
                        }
                    },
                    secondaryButton: .cancel()
                )
            }

            VStack {
                Spacer()
                HStack {
                    Spacer()
                    addTaskButton
                }
            }
        }
        .preferredColorScheme(.light)
    }

    var refreshButton: some View {
        Button(action: {
            observeTasks()
        }) {
            Image(systemName: "arrow.clockwise")
                .resizable()
                .frame(width: 24, height: 24)
                .foregroundColor(.blue)
        }
    }

    var addTaskButton: some View {
        Button(action: {
            showingAddTaskView.toggle()
        }) {
            Image(systemName: "plus")
                .resizable()
                .frame(width: 24, height: 24)
                .foregroundColor(.blue)
                .padding()
                .background(Color.white)
                .clipShape(Circle())
                .shadow(radius: 5)
        }
        .padding()
    }

    var taskListView: some View {
        List {
            ForEach(Array(tasksByMonth.keys.sorted()), id: \.self) { month in
                Section(header: HeaderView(month: month, isExpanded: expandedMonths.contains(month)) {
                    withAnimation {
                        toggleMonthExpansion(month: month)
                    }
                }) {
                    if expandedMonths.contains(month) {
                        ForEach(Array(tasksByMonth[month]?.keys.sorted() ?? []), id: \.self) { date in
                            taskSection(for: date, tasks: tasksByMonth[month]?[date] ?? [])
                        }
                    }
                }
            }
        }
        .refreshable {
            observeTasks()
        }
    }

    @ViewBuilder
    func taskSection(for date: String, tasks: [Task]) -> some View {
        Section(header: Text("\(formattedDayOfWeek(from: date)), \(formattedDate(date))").font(.headline)) {
            ForEach(tasks) { task in
                HStack(alignment: .top, spacing: 16) {
                    TaskCardView(
                        task: task,
                        currentUserName: userSession.currentUserName
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.systemGray6))
                    .cornerRadius(15)
                    .shadow(radius: 4)

                    if task.assignedTo != userSession.currentUserName {
                        CheckBoxView(isChecked: task.isConfirmed) {
                            toggleConfirmation(task: task)
                        }
                        .frame(width: 30, height: 30)
                    } else {
                        CheckBoxView(isChecked: task.isConfirmed) {}
                            .frame(width: 30, height: 30)
                            .disabled(true)
                            .opacity(0.5)
                    }
                }
                .padding(.vertical, 8)
            }
        }
    }

    func observeTasks() {
        guard let familyId = userSession.familyId else { return }

        ref.child(familyId).observe(.value) { snapshot in
            var newTasksByMonth: [String: [String: [Task]]] = [:]
            for child in snapshot.children {
                if let snapshot = child as? DataSnapshot,
                   let dict = snapshot.value as? [String: Any],
                   let title = dict["title"] as? String,
                   let assignedTo = dict["assignedTo"] as? String,
                   let createdBy = dict["createdBy"] as? String,
                   let date = dict["date"] as? String,
                   let isConfirmed = dict["isConfirmed"] as? Bool {

                    let task = Task(
                        id: snapshot.key,
                        title: title,
                        assignedTo: assignedTo,
                        createdBy: createdBy,
                        date: date,
                        isConfirmed: isConfirmed
                    )
                    let month = formattedMonth(from: date)

                    if newTasksByMonth[month] == nil {
                        newTasksByMonth[month] = [date: [task]]
                    } else if newTasksByMonth[month]?[date] == nil {
                        newTasksByMonth[month]?[date] = [task]
                    } else {
                        newTasksByMonth[month]?[date]?.append(task)
                    }
                }
            }
            DispatchQueue.main.async {
                self.tasksByMonth = newTasksByMonth
            }
        }
    }

    func toggleMonthExpansion(month: String) {
        if expandedMonths.contains(month) {
            expandedMonths.remove(month)
        } else {
            expandedMonths.insert(month)
        }
    }

    func toggleConfirmation(task: Task) {
        guard let familyId = userSession.familyId else { return }
        let taskRef = ref.child(familyId).child(task.id)
        taskRef.updateChildValues(["isConfirmed": !task.isConfirmed])
    }

    func deleteTask(task: Task) {
        guard let familyId = userSession.familyId else { return }
        let taskRef = ref.child(familyId).child(task.id)
        taskRef.removeValue { error, _ in
            if let error = error {
                print("Errore durante l'eliminazione del task: \(error.localizedDescription)")
            } else {
                print("Task eliminato con successo")
            }
        }
    }

    func formattedDayOfWeek(from dateString: String) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        guard let date = dateFormatter.date(from: dateString) else { return "" }
        dateFormatter.dateFormat = "EEEE"
        return dateFormatter.string(from: date)
    }

    func formattedDate(_ dateString: String) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        guard let date = dateFormatter.date(from: dateString) else { return "" }
        dateFormatter.dateFormat = "dd MMMM yyyy"
        return dateFormatter.string(from: date)
    }

    func formattedMonth(from dateString: String) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        guard let date = dateFormatter.date(from: dateString) else { return "" }
        dateFormatter.dateFormat = "MMMM yyyy"
        return dateFormatter.string(from: date)
    }
}
