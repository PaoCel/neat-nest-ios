import SwiftUI

struct MainMenuView: View {
    @EnvironmentObject var userSession: UserSession
    @EnvironmentObject private var voiceManager: SmartGroceryVoiceManager
    @State private var showUserOverview = false
    @State private var showSmartGrocery = false

    private var menuItems: [HomeMenuItem] {
        [
            HomeMenuItem(
                title: "Faccende",
                icon: "house.circle.fill",
                destination: AnyView(TasksView())
            ),
            HomeMenuItem(
                title: "Smart Grocery",
                icon: "cart.badge.plus",
                destination: AnyView(SmartGroceryHomeView(userSession: userSession))
            ),
            HomeMenuItem(
                title: "Soldi",
                icon: "eurosign.circle.fill",
                destination: AnyView(MoneyHomeView(userSession: userSession))
            ),
            HomeMenuItem(
                title: "Dispensa",
                icon: "shippingbox.circle.fill",
                destination: AnyView(PantryHomeView(userSession: userSession))
            ),
            HomeMenuItem(
                title: "Ricette",
                icon: "fork.knife.circle.fill",
                destination: AnyView(RecipeHomeView(userSession: userSession))
            ),
            HomeMenuItem(
                title: "Scontrini",
                icon: "doc.text.viewfinder",
                destination: AnyView(ReceiptScanHomeView(userSession: userSession))
            )
        ]
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    welcomeHeader

                    if let voiceResult = voiceManager.lastProcessedResult {
                        voiceBanner(result: voiceResult)
                    }

                    menuSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 32)
            }
            .background(backgroundView.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    profileButton
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(isPresented: $showSmartGrocery) {
                SmartGroceryHomeView(userSession: userSession)
            }
            .sheet(isPresented: $showUserOverview) {
                UserOverviewView(currentUserName: userSession.currentUserName)
                    .environmentObject(userSession)
            }
            .alert("Smart Grocery", isPresented: voiceErrorBinding) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(voiceManager.errorMessage ?? "")
            }
        }
        .preferredColorScheme(.light)
    }

    private var backgroundView: some View {
        LinearGradient(
            colors: [
                Color(uiColor: .systemGray6),
                Color.white
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var menuSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("La tua casa, a colpo d'occhio")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.primary)

                    Text("Scegli un'area e continua da dove avevi lasciato.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 14),
                    GridItem(.flexible(), spacing: 14)
                ],
                spacing: 14
            ) {
                ForEach(Array(menuItems.enumerated()), id: \.element.id) { index, item in
                    NavigationLink(destination: item.destination) {
                        MenuItemView(item: item, style: MenuItemStyle.style(for: index))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var welcomeHeader: some View {
        let greeting = userSession.currentUserGender == "Femmina" ? "Bentornata" : "Bentornato"

        return VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                profileBadge

                VStack(alignment: .leading, spacing: 6) {
                    Text(greeting)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Text(userSession.currentUserName)
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                }

                Spacer()
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Centro di controllo NeatNest")
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text("Apri rapidamente spesa, budget e le altre aree della casa senza perdere orientamento.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(Color.white.opacity(0.92))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .stroke(Color.black.opacity(0.04), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.05), radius: 18, x: 0, y: 10)
        }
    }

    private func voiceBanner(result: SmartGroceryVoiceProcessedResult) -> some View {
        Button {
            showSmartGrocery = true
        } label: {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "mic.badge.plus")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(Color.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                VStack(alignment: .leading, spacing: 6) {
                    Text("Aggiunto con Siri")
                        .font(.headline)
                        .foregroundStyle(.white)

                    Text("\(result.itemName) e ora nella Smart Grocery")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.92))

                    Text("Apri Smart Grocery")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                }

                Spacer(minLength: 0)

                Image(systemName: "arrow.right")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)
            }
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.indigo, Color.cyan],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .shadow(color: Color.indigo.opacity(0.16), radius: 16, x: 0, y: 10)
        }
        .buttonStyle(.plain)
    }

    private var profileButton: some View {
        Button {
            showUserOverview.toggle()
        } label: {
            profileBadge
        }
        .buttonStyle(.plain)
    }

    private var profileBadge: some View {
        let initials = userInitials

        return ZStack(alignment: .bottomTrailing) {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color.blue, Color.cyan],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 48, height: 48)
                .shadow(color: Color.blue.opacity(0.2), radius: 10, x: 0, y: 6)

            Text(initials)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)

            Circle()
                .fill(Color.white)
                .frame(width: 14, height: 14)
                .overlay(
                    Circle()
                        .fill(Color.green)
                        .padding(3)
                )
        }
        .accessibilityLabel("Profilo utente \(userSession.currentUserName)")
    }

    private var userInitials: String {
        let parts = userSession.currentUserName
            .split(separator: " ")
            .prefix(2)
            .compactMap { $0.first.map(String.init) }

        let initials = parts.joined()
        if !initials.isEmpty {
            return initials.uppercased()
        }

        return String(userSession.currentUserName.prefix(2)).uppercased()
    }

    private var voiceErrorBinding: Binding<Bool> {
        Binding(
            get: { voiceManager.errorMessage != nil },
            set: { newValue in
                if !newValue {
                    voiceManager.errorMessage = nil
                }
            }
        )
    }
}

struct MenuItemStyle {
    let accent: Color
    let background: [Color]

    static func style(for index: Int) -> MenuItemStyle {
        let styles: [MenuItemStyle] = [
            MenuItemStyle(accent: .orange, background: [Color.orange.opacity(0.18), Color.white]),
            MenuItemStyle(accent: .green, background: [Color.green.opacity(0.18), Color.white]),
            MenuItemStyle(accent: .blue, background: [Color.blue.opacity(0.18), Color.white]),
            MenuItemStyle(accent: .brown, background: [Color.brown.opacity(0.16), Color.white])
        ]

        return styles[index % styles.count]
    }
}

struct MenuItemView: View {
    let item: HomeMenuItem
    let style: MenuItemStyle

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(style.accent.opacity(0.12))
                    .frame(width: 52, height: 52)

                Image(systemName: item.icon)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(style.accent)
            }

            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 6) {
                Text(item.title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)

                Text(menuSubtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack {
                Text("Apri")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(style.accent)

                Spacer()

                Image(systemName: "arrow.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(style.accent)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 184, alignment: .leading)
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: style.background,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(style.accent.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: style.accent.opacity(0.08), radius: 18, x: 0, y: 10)
    }

    private var menuSubtitle: String {
        switch item.title {
        case "Faccende":
            return "Attivita domestiche e promemoria condivisi."
        case "Smart Grocery":
            return "Liste, suggerimenti e storico della spesa."
        case "Budget":
            return "Entrate, uscite e riepilogo del mese."
        case "Dispensa":
            return "Scorte e prodotti disponibili in casa."
        default:
            return "Apri l'area dedicata."
        }
    }
}

@MainActor
private struct MainMenuViewPreviewContainer: View {
    private let session = PreviewSupport.makeUserSession()
    private let voiceManager = PreviewSupport.makeVoiceManager()

    var body: some View {
        MainMenuView()
            .environmentObject(session)
            .environmentObject(voiceManager)
    }
}

#Preview("Main Menu") {
    MainMenuViewPreviewContainer()
}
