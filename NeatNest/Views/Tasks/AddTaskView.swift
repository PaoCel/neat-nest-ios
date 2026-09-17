import SwiftUI

struct AddTaskView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var viewModel: AddTaskViewModel

    init(userSession: UserSession) {
        _viewModel = State(initialValue: AddTaskViewModel(userSession: userSession))
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    if viewModel.isLoading {
                        ProgressView("Caricamento utenti...")
                    } else {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Faccenda")
                                .font(.headline)
                            TextField("Inserisci una faccenda", text: $viewModel.taskTitle)
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(10)
                                .shadow(radius: 4)

                            Text("Assegna a")
                                .font(.headline)
                            if viewModel.users.isEmpty {
                                Text("Caricamento utenti...")
                                    .foregroundColor(.gray)
                                    .padding()
                                    .frame(maxWidth: .infinity, minHeight: 80)
                                    .background(Color(.systemGray6))
                                    .cornerRadius(10)
                                    .shadow(radius: 4)
                            } else {
                                Picker("Seleziona chi", selection: $viewModel.selectedUser) {
                                    ForEach(viewModel.users, id: \.self) { user in
                                        Text(user).tag(user)
                                    }
                                }
                                .pickerStyle(MenuPickerStyle())
                                .padding()
                                .frame(maxWidth: .infinity, minHeight: 80, alignment: .leading)
                                .background(Color(.systemGray6))
                                .cornerRadius(10)
                                .shadow(radius: 4)
                            }

                            Text("Data")
                                .font(.headline)
                            DatePicker("Seleziona data", selection: $viewModel.selectedDate, displayedComponents: .date)
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(10)
                                .shadow(radius: 4)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        .shadow(radius: 4)
                        .frame(maxWidth: .infinity)
                    }

                    Spacer()

                    Button(action: {
                        viewModel.addTask { success in
                            if success {
                                presentationMode.wrappedValue.dismiss()
                            }
                        }
                    }) {
                        HStack {
                            Image(systemName: "plus.circle")
                                .resizable()
                                .frame(width: 24, height: 24)
                                .foregroundColor(.green)
                            Text("Aggiungi Faccenda")
                                .font(.subheadline)
                                .foregroundColor(.green)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.white)
                        .cornerRadius(10)
                        .shadow(radius: 4)
                    }
                    .disabled(viewModel.taskTitle.isEmpty || viewModel.selectedUser.isEmpty)
                    .padding(.top, 20)
                }
                .padding()
                .alert(
                    isPresented: Binding<Bool>(
                        get: { viewModel.errorMessage != nil },
                        set: {
                            if !$0 {
                                viewModel.errorMessage = nil
                            }
                        }
                    )
                ) {
                    Alert(
                        title: Text("Errore"),
                        message: Text(viewModel.errorMessage ?? "Errore sconosciuto"),
                        dismissButton: .default(Text("OK"))
                    )
                }
            }
            .navigationTitle("Nuova Faccenda")
            .navigationBarItems(leading: Button("Annulla") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
}
