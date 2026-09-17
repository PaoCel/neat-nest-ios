import SwiftUI
import FirebaseDatabase
import FirebaseAuth

struct DettaglioListaView: View {
    let shoppingList: ShoppingList
    @EnvironmentObject var userSession: UserSession
    @State private var products: [Product] = []
    @State private var isAddingProduct = false
    @State private var totalCost: Double = 0

    private var productsRef: DatabaseReference {
        Database.database().reference()
            .child("shoppingLists")
            .child(userSession.familyId ?? "")
            .child(shoppingList.id)
            .child("products")
    }

    var body: some View {
        ZStack {
            List {
                Section(header: Text("Prodotti")) {
                    ForEach(products) { product in
                        ProductRow(product: product) { updatedProduct in
                            updateProduct(updatedProduct)
                        } onDelete: {
                            deleteProduct(product)
                        }
                    }
                }
            }

            VStack {
                Spacer()
                HStack {
                    Text("Totale: \(totalCost, format: .euro)")
                        .font(.headline)
                        .padding()
                        .background(Color.white)
                        .cornerRadius(10)
                        .shadow(radius: 2)

                    Spacer()

                    Button(action: { isAddingProduct.toggle() }) {
                        Image(systemName: "plus")
                            .resizable()
                            .frame(width: 24, height: 24)
                            .foregroundColor(.blue)
                            .padding()
                            .background(Color.white)
                            .clipShape(Circle())
                            .shadow(radius: 5)
                    }
                }
                .padding()
            }
        }
        .navigationTitle(shoppingList.title)
        .sheet(isPresented: $isAddingProduct) {
            AddProductView(
                isPresented: $isAddingProduct,
                onSave: addProduct
            )
        }
        .onAppear {
            observeProducts()
        }
    }

    private func observeProducts() {
        productsRef.observe(.value) { snapshot in
            var newProducts: [Product] = []
            var newTotalCost: Double = 0

            for child in snapshot.children {
                if let snapshot = child as? DataSnapshot,
                   let dict = snapshot.value as? [String: Any],
                   let name = dict["name"] as? String,
                   let addedBy = dict["addedBy"] as? String,
                   let isPurchased = dict["isPurchased"] as? Bool,
                   let category = dict["category"] as? String {

                    let cost = dict["cost"] as? Double ?? 0

                    let product = Product(
                        id: snapshot.key,
                        name: name,
                        addedBy: addedBy,
                        isPurchased: isPurchased,
                        category: category,
                        cost: cost
                    )
                    newProducts.append(product)
                    if product.isPurchased {
                        newTotalCost += product.cost
                    }
                }
            }

            DispatchQueue.main.async {
                self.products = newProducts
                self.totalCost = newTotalCost
                updateShoppingListStatus(totalCost: newTotalCost)
            }
        }
    }

    private func addProduct(name: String, category: String) {
        let newProduct: [String: Any] = [
            "name": name,
            "addedBy": userSession.currentUserName,
            "isPurchased": false,
            "category": category,
            "cost": 0.0
        ]

        let newProductRef = productsRef.childByAutoId()
        newProductRef.setValue(newProduct)
    }

    private func updateProduct(_ product: Product) {
        let updates: [String: Any] = [
            "isPurchased": product.isPurchased,
            "cost": product.cost
        ]
        productsRef.child(product.id).updateChildValues(updates)
        updateShoppingListStatus(totalCost: calculateTotalCost())
    }

    private func deleteProduct(_ product: Product) {
        productsRef.child(product.id).removeValue()
        updateShoppingListStatus(totalCost: calculateTotalCost())
    }

    private func calculateTotalCost() -> Double {
        products.filter { $0.isPurchased }.reduce(0) { $0 + $1.cost }
    }

    private func updateShoppingListStatus(totalCost: Double) {
        let isCompleted = !products.isEmpty && products.allSatisfy { $0.isPurchased }

        Database.database().reference()
            .child("shoppingLists")
            .child(userSession.familyId ?? "")
            .child(shoppingList.id)
            .updateChildValues([
                "isCompleted": isCompleted,
                "totalCost": totalCost
            ])
    }
}

struct ProductRow: View {
    let product: Product
    let onUpdate: (Product) -> Void
    let onDelete: () -> Void
    @State private var showingCostAlert = false
    @State private var costInput = ""

    var body: some View {
        HStack {
            Button(action: {
                if !product.isPurchased {
                    showingCostAlert = true
                } else {
                    var updatedProduct = product
                    updatedProduct.isPurchased.toggle()
                    updatedProduct.cost = 0
                    onUpdate(updatedProduct)
                }
            }) {
                Image(systemName: product.isPurchased ? "checkmark.square.fill" : "square")
                    .foregroundColor(product.isPurchased ? .green : .gray)
            }
            .buttonStyle(BorderlessButtonStyle())
            .alert("Inserisci il costo", isPresented: $showingCostAlert) {
                TextField("Costo (€)", text: $costInput)
                    .keyboardType(.decimalPad)
                Button("OK") {
                    var updatedProduct = product
                    updatedProduct.isPurchased = true
                    updatedProduct.cost = Double(costInput.replacingOccurrences(of: ",", with: ".")) ?? 0
                    onUpdate(updatedProduct)
                    costInput = ""
                }
                Button("Annulla", role: .cancel) {
                    costInput = ""
                }
            } message: {
                Text("Inserisci il costo del prodotto (€)")
            }

            VStack(alignment: .leading) {
                Text(product.name)
                    .strikethrough(product.isPurchased)
                Text(product.category)
                    .font(.caption)
                    .foregroundColor(.gray)
                HStack {
                    Text("Aggiunto da: \(product.addedBy)")
                        .font(.caption2)
                        .foregroundColor(.gray)
                    if product.isPurchased {
                        Text(product.cost, format: .euro)
                            .font(.caption2)
                            .foregroundColor(.blue)
                    }
                }
            }

            Spacer()

            Button(action: onDelete) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
            .buttonStyle(BorderlessButtonStyle())
        }
        .contentShape(Rectangle())
    }
}

struct AddProductView: View {
    @Binding var isPresented: Bool
    let onSave: (String, String) -> Void

    @State private var productName = ""
    @State private var category = ""

    var body: some View {
        NavigationView {
            Form {
                TextField("Nome prodotto", text: $productName)
                TextField("Categoria", text: $category)
            }
            .navigationTitle("Nuovo Prodotto")
            .navigationBarItems(
                leading: Button("Annulla") {
                    isPresented = false
                },
                trailing: Button("Salva") {
                    onSave(productName, category)
                    isPresented = false
                }
                .disabled(productName.isEmpty)
            )
        }
    }
}

struct MonthHeaderView: View {
    let month: String
    let isExpanded: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(month)
                    .font(.headline)
                Spacer()
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
            }
        }
    }
}
