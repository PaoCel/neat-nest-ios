import SwiftUI

@MainActor
private struct SmartGroceryFlowPreviewContainer: View {
    private let session = PreviewSupport.makeUserSession()
    private let voiceManager = PreviewSupport.makeVoiceManager()

    var body: some View {
        NavigationStack {
            List {
                Section("Panoramica") {
                    NavigationLink("Home") {
                        SmartGroceryHomeView(
                            userSession: session,
                            viewModel: PreviewSupport.makeSmartGroceryHomeViewModel()
                        )
                    }

                    NavigationLink("Liste") {
                        GroceryListsView(
                            userSession: session,
                            viewModel: PreviewSupport.makeGroceryListsViewModel()
                        )
                    }

                    NavigationLink("Dettaglio lista principale") {
                        GroceryListDetailView(
                            list: PreviewSupport.defaultList,
                            userSession: session,
                            viewModel: PreviewSupport.makeGroceryListDetailViewModel()
                        )
                        .environmentObject(voiceManager)
                    }

                    NavigationLink("Spesa & storico") {
                        SmartGrocerySpendingView(
                            userSession: session,
                            viewModel: PreviewSupport.makeSmartGrocerySpendingViewModel()
                        )
                    }
                }

                Section("Utility") {
                    NavigationLink("Impostazioni") {
                        SmartGrocerySettingsView()
                    }

                    NavigationLink("Aggiungi con Siri") {
                        SmartGroceryVoiceAssistantView()
                            .environmentObject(voiceManager)
                    }
                }
            }
            .navigationTitle("Smart Grocery Flow")
        }
        .environmentObject(voiceManager)
    }
}

#Preview("Smart Grocery Flow") {
    SmartGroceryFlowPreviewContainer()
}
