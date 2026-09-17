import SwiftUI
import FirebaseDatabase
import FirebaseAuth

struct ListaSpesaView: View {
    @EnvironmentObject var userSession: UserSession
    @State private var listsByMonth: [String: [String: [ShoppingList]]] = [:]
    @State private var expandedMonths: Set<String> = []
    @State private var isAddingList = false
    @State private var newListTitle = ""

    private var ref: DatabaseReference = Database.database().reference().child("shoppingLists")

    var body: some View {
        ZStack {
            VStack {
                listaSpesaHeaderView
                shoppingListView
            }

            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button(action: { isAddingList.toggle() }) {
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
            }
        }
        .navigationTitle("Lista della Spesa")
        .onAppear {
            observeShoppingLists()
        }
        .sheet(isPresented: $isAddingList) {
            addNewListView
        }
    }

    private var listaSpesaHeaderView: some View {
        HStack {
            let greeting = userSession.currentUserGender == "Femmina" ? "Bentornata" : "Bentornato"
            Text("\(greeting), \(userSession.currentUserName)")
                .font(.headline)
                .padding()
            Spacer()
        }
    }

    private var shoppingListView: some View {
        List {
            ForEach(Array(listsByMonth.keys.sorted()), id: \.self) { month in
                Section(header: MonthHeaderView(month: month, isExpanded: expandedMonths.contains(month)) {
                    toggleMonthExpansion(month: month)
                }) {
                    if expandedMonths.contains(month) {
                        ForEach(Array(listsByMonth[month]?.keys.sorted() ?? []), id: \.self) { date in
                            shoppingListSection(for: date, lists: listsByMonth[month]?[date] ?? [])
                        }
                    }
                }
            }
        }
        .listStyle(InsetGroupedListStyle())
    }

    private var addNewListView: some View {
        NavigationView {
            Form {
                TextField("Titolo della lista", text: $newListTitle)
                Button("Salva") {
                    addNewShoppingList()
                }
                .disabled(newListTitle.isEmpty)
            }
            .navigationTitle("Nuova Lista")
            .navigationBarItems(trailing: Button("Annulla") {
                isAddingList = false
            })
        }
    }

    private func addNewShoppingList() {
        guard let familyId = userSession.familyId else { return }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let currentDate = dateFormatter.string(from: Date())

        let newList: [String: Any] = [
            "title": newListTitle,
            "createdBy": userSession.currentUserName,
            "date": currentDate,
            "isCompleted": false,
            "totalCost": 0.0,
            "products": [:]
        ]

        let newListRef = ref.child(familyId).childByAutoId()
        newListRef.setValue(newList) { error, _ in
            if let error = error {
                print("Error saving shopping list: \(error.localizedDescription)")
            } else {
                DispatchQueue.main.async {
                    isAddingList = false
                    newListTitle = ""
                }
            }
        }
    }

    private func observeShoppingLists() {
        guard let familyId = userSession.familyId else { return }

        ref.child(familyId).observe(.value) { snapshot in
            var newListsByMonth: [String: [String: [ShoppingList]]] = [:]

            for child in snapshot.children {
                if let snapshot = child as? DataSnapshot,
                   let dict = snapshot.value as? [String: Any],
                   let title = dict["title"] as? String,
                   let createdBy = dict["createdBy"] as? String,
                   let date = dict["date"] as? String {

                    let isCompleted = dict["isCompleted"] as? Bool ?? false
                    let totalCost = dict["totalCost"] as? Double ?? 0

                    let list = ShoppingList(
                        id: snapshot.key,
                        title: title,
                        createdBy: createdBy,
                        date: date,
                        isCompleted: isCompleted,
                        totalCost: totalCost
                    )

                    let month = formattedMonth(from: date)

                    if newListsByMonth[month] == nil {
                        newListsByMonth[month] = [date: [list]]
                    } else if newListsByMonth[month]?[date] == nil {
                        newListsByMonth[month]?[date] = [list]
                    } else {
                        newListsByMonth[month]?[date]?.append(list)
                    }
                }
            }

            DispatchQueue.main.async {
                self.listsByMonth = newListsByMonth
            }
        }
    }

    @ViewBuilder
    private func shoppingListSection(for date: String, lists: [ShoppingList]) -> some View {
        ForEach(lists) { list in
            NavigationLink(destination: DettaglioListaView(shoppingList: list)) {
                HStack {
                    VStack(alignment: .leading) {
                        Text(list.title)
                            .font(.headline)
                        HStack {
                            Text("Creato da: \(list.createdBy)")
                                .font(.caption)
                                .foregroundColor(.gray)
                            if list.totalCost > 0 {
                                Text(list.totalCost, format: .euro)
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    Spacer()
                    if list.isCompleted {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }
                }
            }
        }
    }

    private func toggleMonthExpansion(month: String) {
        if expandedMonths.contains(month) {
            expandedMonths.remove(month)
        } else {
            expandedMonths.insert(month)
        }
    }

    private func formattedMonth(from dateString: String) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        guard let date = dateFormatter.date(from: dateString) else { return "" }
        dateFormatter.dateFormat = "MMMM yyyy"
        return dateFormatter.string(from: date)
    }
}
