import SwiftUI
import FirebaseAuth
import FirebaseCore
import FirebaseDatabase

struct UserOverviewView: View {
    @EnvironmentObject var userSession: UserSession
    @State var currentUserName: String
    @Environment(\.presentationMode) var presentationMode

    @State private var completedTasks: [Task] = []
    @State private var pendingTasks: [Task] = []
    @State private var completedShoppingLists: [ShoppingList] = []
    @State private var pendingShoppingLists: [ShoppingList] = []
    @State private var selectedTab = 0
    @State private var showingChangePasswordView = false
    @State private var showingChangeUsernameView = false
    @State private var showingDeleteAccountAlert = false

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                headerSection

                TabView(selection: $selectedTab) {
                    tasksOverviewView
                        .tag(0)

                    shoppingListsOverviewView
                        .tag(1)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))

                customTabSelector
                actionButtons
            }
            .navigationBarItems(leading: Button("Chiudi") {
                presentationMode.wrappedValue.dismiss()
            })
            .onAppear {
                fetchTasks()
                fetchShoppingLists()
            }
        }
        .preferredColorScheme(.light)
    }

    private var headerSection: some View {
        VStack(spacing: 8) {
            Text("Riepilogo di \(currentUserName)")
                .font(.largeTitle)
                .fontWeight(.bold)

            if let familyId = userSession.familyId, !familyId.isEmpty {
                Text("Codice Nucleo Familiare: \(familyId)")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
        }
        .padding(.top)
    }

    private var customTabSelector: some View {
        HStack(spacing: 0) {
            tabButton("Faccende", index: 0)
            tabButton("Lista Spesa", index: 1)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
        .cornerRadius(15)
        .padding(.horizontal)
    }

    private func tabButton(_ title: String, index: Int) -> some View {
        Button(action: {
            withAnimation {
                selectedTab = index
            }
        }) {
            Text(title)
                .font(.headline)
                .padding(.vertical, 8)
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(selectedTab == index ? Color.blue : Color.clear)
                )
                .foregroundColor(selectedTab == index ? .white : .gray)
        }
    }

    private var tasksOverviewView: some View {
        VStack(spacing: 16) {
            overviewCard(
                title: "Faccende in Sospeso",
                count: pendingTasks.count,
                color: .orange
            )

            overviewCard(
                title: "Faccende Completate",
                count: completedTasks.count,
                color: .green
            )

            ScrollView {
                LazyVStack(spacing: 12) {
                    if !pendingTasks.isEmpty {
                        taskSection(title: "Da Completare", tasks: pendingTasks)
                    }

                    if !completedTasks.isEmpty {
                        taskSection(title: "Completate", tasks: completedTasks)
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private var shoppingListsOverviewView: some View {
        VStack(spacing: 16) {
            overviewCard(
                title: "Liste Attive",
                count: pendingShoppingLists.count,
                color: .orange
            )

            overviewCard(
                title: "Liste Completate",
                count: completedShoppingLists.count,
                color: .green
            )

            ScrollView {
                LazyVStack(spacing: 12) {
                    if !pendingShoppingLists.isEmpty {
                        shoppingListSection(title: "Liste Attive", lists: pendingShoppingLists)
                    }

                    if !completedShoppingLists.isEmpty {
                        shoppingListSection(title: "Liste Completate", lists: completedShoppingLists)
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private var actionButtons: some View {
        HStack {
            actionButton(
                title: "Logout",
                icon: "arrowshape.turn.up.left.fill",
                color: .red
            ) {
                logoutUser()
            }

            actionButton(
                title: "Cambia Password",
                icon: "lock.fill",
                color: .blue
            ) {
                showingChangePasswordView = true
            }
            .sheet(isPresented: $showingChangePasswordView) {
                ChangePasswordView()
            }

            actionButton(
                title: "Cambia Nome",
                icon: "person.crop.circle.fill",
                color: .blue
            ) {
                showingChangeUsernameView = true
            }
            .sheet(isPresented: $showingChangeUsernameView) {
                ChangeUsernameView(currentUserName: $currentUserName)
            }

            actionButton(
                title: "Elimina Account",
                icon: "trash.fill",
                color: .red
            ) {
                showingDeleteAccountAlert = true
            }
        }
        .padding()
        .alert(isPresented: $showingDeleteAccountAlert) {
            Alert(
                title: Text("Conferma Eliminazione"),
                message: Text("Sei sicuro di voler eliminare definitivamente il tuo account?"),
                primaryButton: .destructive(Text("Elimina")) {
                    deleteUserAccount()
                },
                secondaryButton: .cancel()
            )
        }
    }

    private func overviewCard(title: String, count: Int, color: Color) -> some View {
        HStack {
            Text(title)
                .font(.headline)
            Spacer()
            Text("\(count)")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
        .padding(.horizontal)
    }

    private func taskSection(title: String, tasks: [Task]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .padding(.top)

            ForEach(tasks) { task in
                TaskRowView(task: task)
            }
        }
    }

    private func shoppingListSection(title: String, lists: [ShoppingList]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .padding(.top)

            ForEach(lists) { list in
                ShoppingListRowView(list: list)
            }
        }
    }

    private func actionButton(title: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack {
                Image(systemName: icon)
                    .resizable()
                    .frame(width: 24, height: 24)
                Text(title)
                    .font(.caption)
            }
            .foregroundColor(color)
        }
    }

    private func fetchTasks() {
        guard isRealtimeDatabaseConfigured else {
            completedTasks = []
            pendingTasks = []
            return
        }

        guard let familyId = userSession.familyId else { return }

        let userTasksRef = Database.database().reference()
            .child("tasks")
            .child(familyId)
            .queryOrdered(byChild: "assignedTo")
            .queryEqual(toValue: currentUserName)

        userTasksRef.observeSingleEvent(of: .value) { snapshot in
            var completed: [Task] = []
            var pending: [Task] = []

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

                    if isConfirmed {
                        completed.append(task)
                    } else {
                        pending.append(task)
                    }
                }
            }

            DispatchQueue.main.async {
                self.completedTasks = completed
                self.pendingTasks = pending
            }
        }
    }

    private func fetchShoppingLists() {
        guard isRealtimeDatabaseConfigured else {
            completedShoppingLists = []
            pendingShoppingLists = []
            return
        }

        guard let familyId = userSession.familyId else { return }

        let shoppingListsRef = Database.database().reference()
            .child("shoppingLists")
            .child(familyId)

        shoppingListsRef.observeSingleEvent(of: .value) { snapshot in
            var completed: [ShoppingList] = []
            var pending: [ShoppingList] = []

            for child in snapshot.children {
                if let snapshot = child as? DataSnapshot,
                   let dict = snapshot.value as? [String: Any],
                   let title = dict["title"] as? String,
                   let createdBy = dict["createdBy"] as? String,
                   let date = dict["date"] as? String,
                   let isCompleted = dict["isCompleted"] as? Bool {

                    let totalCost = dict["totalCost"] as? Double ?? 0

                    let list = ShoppingList(
                        id: snapshot.key,
                        title: title,
                        createdBy: createdBy,
                        date: date,
                        isCompleted: isCompleted,
                        totalCost: totalCost
                    )

                    if isCompleted {
                        completed.append(list)
                    } else {
                        pending.append(list)
                    }
                }
            }

            DispatchQueue.main.async {
                self.completedShoppingLists = completed
                self.pendingShoppingLists = pending
            }
        }
    }

    func logoutUser() {
        userSession.logout()
        presentationMode.wrappedValue.dismiss()
    }

    func deleteUserAccount() {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("Debug: Nessun utente autenticato.")
            return
        }

        UserProfileManager.deleteUserProfile(userId: userId) { result in
            switch result {
            case .failure(let error):
                print("Errore durante l'eliminazione dei dati utente: \(error.localizedDescription)")
            case .success:
                Auth.auth().currentUser?.delete { authError in
                    if let authError = authError {
                        print("Errore durante l'eliminazione dell'account: \(authError.localizedDescription)")
                    } else {
                        print("Account eliminato con successo.")
                        logoutUser()
                    }
                }
            }
        }
    }

    func formattedDayAndDate(_ dateString: String) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        guard let date = dateFormatter.date(from: dateString) else { return "" }
        dateFormatter.dateFormat = "EEEE, dd MMMM yyyy"
        return dateFormatter.string(from: date)
    }

    private var isRealtimeDatabaseConfigured: Bool {
        FirebaseApp.app()?.options.databaseURL?.isEmpty == false
    }
}

extension UserOverviewView {
    struct TaskRowView: View {
        let task: Task

        var body: some View {
            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(.subheadline)
                    .fontWeight(.medium)

                HStack {
                    Text(task.assignedTo)
                        .font(.caption)
                        .foregroundColor(.blue)

                    Spacer()

                    Text(formattedDate(task.date))
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            .padding()
            .background(Color(.systemGray5))
            .cornerRadius(8)
        }
    }

    struct ShoppingListRowView: View {
        let list: ShoppingList

        var body: some View {
            VStack(alignment: .leading, spacing: 4) {
                Text(list.title)
                    .font(.subheadline)
                    .fontWeight(.medium)

                HStack {
                    Text("Creato da: \(list.createdBy)")
                        .font(.caption)
                        .foregroundColor(.gray)

                    Spacer()

                    if list.totalCost > 0 {
                        Text(list.totalCost, format: .euro)
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
            }
            .padding()
            .background(Color(.systemGray5))
            .cornerRadius(8)
        }
    }
}

struct ChangeUsernameView: View {
    @Binding var currentUserName: String
    @State private var newUserName: String = ""
    @EnvironmentObject var userSession: UserSession
    @Environment(\.presentationMode) var presentationMode
    @State private var showingConfirmationAlert = false
    @State private var showingErrorAlert = false
    @State private var alertMessage = ""

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                TextField("Nuovo Nome Utente", text: $newUserName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding()

                Button(action: changeUsername) {
                    Text("Aggiorna Nome Utente")
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .cornerRadius(10)
                }
                .padding()
                .alert(isPresented: $showingConfirmationAlert) {
                    Alert(
                        title: Text("Conferma"),
                        message: Text(alertMessage),
                        dismissButton: .default(Text("OK")) {
                            presentationMode.wrappedValue.dismiss()
                        }
                    )
                }
                .alert(isPresented: $showingErrorAlert) {
                    Alert(
                        title: Text("Errore"),
                        message: Text(alertMessage),
                        dismissButton: .default(Text("OK"))
                    )
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Cambia Nome Utente")
            .navigationBarItems(leading: Button("Annulla") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }

    func changeUsername() {
        guard !newUserName.isEmpty else {
            alertMessage = "Il nuovo nome utente non può essere vuoto."
            showingErrorAlert = true
            return
        }

        guard let userId = Auth.auth().currentUser?.uid else {
            alertMessage = "Errore nel recuperare l'utente corrente."
            showingErrorAlert = true
            return
        }

        UserProfileManager.updateUserName(
            userId: userId,
            userName: newUserName,
            familyId: userSession.familyId
        ) { result in
            DispatchQueue.main.async {
                switch result {
                case .failure(let error):
                    alertMessage = "Errore durante l'aggiornamento del nome utente: \(error.localizedDescription)"
                    showingErrorAlert = true
                case .success:
                    alertMessage = "Nome utente aggiornato con successo."
                    currentUserName = newUserName
                    userSession.currentUserName = newUserName
                    showingConfirmationAlert = true
                }
            }
        }
    }
}

struct ChangePasswordView: View {
    @State private var currentPassword: String = ""
    @State private var newPassword: String = ""
    @State private var confirmPassword: String = ""
    @Environment(\.presentationMode) var presentationMode
    @State private var showingConfirmationAlert = false
    @State private var showingErrorAlert = false
    @State private var alertMessage = ""

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                VStack {
                    SecureFieldWithToggle(text: $currentPassword, placeholder: "Password attuale")
                    SecureFieldWithToggle(text: $newPassword, placeholder: "Nuova Password")
                    SecureFieldWithToggle(text: $confirmPassword, placeholder: "Conferma Nuova Password")
                }

                Button(action: changePassword) {
                    Text("Aggiorna Password")
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .cornerRadius(10)
                }
                .padding()
                .alert(isPresented: $showingConfirmationAlert) {
                    Alert(
                        title: Text("Conferma"),
                        message: Text(alertMessage),
                        dismissButton: .default(Text("OK")) {
                            presentationMode.wrappedValue.dismiss()
                        }
                    )
                }
                .alert(isPresented: $showingErrorAlert) {
                    Alert(
                        title: Text("Errore"),
                        message: Text(alertMessage),
                        dismissButton: .default(Text("OK"))
                    )
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Cambia Password")
            .navigationBarItems(leading: Button("Annulla") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }

    func changePassword() {
        guard newPassword == confirmPassword else {
            alertMessage = "Le nuove password non corrispondono."
            showingErrorAlert = true
            return
        }
        Auth.auth().currentUser?.reauthenticate(
            with: EmailAuthProvider.credential(
                withEmail: Auth.auth().currentUser?.email ?? "",
                password: currentPassword
            )
        ) { _, error in
            if let error = error {
                alertMessage = "Errore di autenticazione: \(error.localizedDescription)"
                showingErrorAlert = true
            } else {
                Auth.auth().currentUser?.updatePassword(to: newPassword) { error in
                    if let error = error {
                        alertMessage = "Errore nell'aggiornamento della password: \(error.localizedDescription)"
                        showingErrorAlert = true
                    } else {
                        alertMessage = "Password aggiornata con successo."
                        showingConfirmationAlert = true
                    }
                }
            }
        }
    }
}

struct SecureFieldWithToggle: View {
    @Binding var text: String
    var placeholder: String
    @State private var isSecure: Bool = true

    var body: some View {
        HStack {
            if isSecure {
                SecureField(placeholder, text: $text)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            } else {
                TextField(placeholder, text: $text)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            Button(action: {
                isSecure.toggle()
            }) {
                Image(systemName: isSecure ? "eye.slash.fill" : "eye.fill")
                    .foregroundColor(.gray)
            }
        }
        .padding()
    }
}

private func formattedDate(_ dateString: String) -> String {
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy-MM-dd"
    guard let date = dateFormatter.date(from: dateString) else { return "" }
    dateFormatter.dateFormat = "dd MMM yyyy"
    return dateFormatter.string(from: date)
}
