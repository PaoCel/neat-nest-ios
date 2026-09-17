import SwiftUI

struct AuthBackgroundView: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(red: 0.95, green: 0.98, blue: 0.95),
                Color(red: 0.99, green: 0.97, blue: 0.92),
                Color.white
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(alignment: .topTrailing) {
            Circle()
                .fill(Color.green.opacity(0.12))
                .frame(width: 220, height: 220)
                .blur(radius: 12)
                .offset(x: 60, y: -40)
        }
        .overlay(alignment: .bottomLeading) {
            Circle()
                .fill(Color.orange.opacity(0.1))
                .frame(width: 200, height: 200)
                .blur(radius: 14)
                .offset(x: -40, y: 70)
        }
        .ignoresSafeArea()
    }
}

struct AuthHeroCard: View {
    let iconName: String
    let eyebrow: String
    let title: String
    let subtitle: String
    let tint: Color
    var trailingBadge: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                HStack(spacing: 12) {
                    Image(systemName: iconName)
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(Color.white.opacity(0.18))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(eyebrow.uppercased())
                            .font(.caption.weight(.bold))
                            .tracking(0.8)
                            .foregroundStyle(.white.opacity(0.82))

                        Text(title)
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Spacer(minLength: 12)

                if let trailingBadge {
                    AuthPill(title: trailingBadge, tint: .white, foreground: tint)
                }
            }

            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.92))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [tint.opacity(0.92), tint.opacity(0.72)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .shadow(color: tint.opacity(0.16), radius: 24, x: 0, y: 16)
    }
}

struct AuthCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            content
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.88))
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.white.opacity(0.7), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.06), radius: 22, x: 0, y: 14)
    }
}

struct AuthSectionHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.title3.weight(.semibold))
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

struct AuthFieldCard<Content: View>: View {
    let title: String
    let iconName: String
    var helper: String? = nil
    var isInvalid: Bool = false
    let content: Content

    init(
        title: String,
        iconName: String,
        helper: String? = nil,
        isInvalid: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.iconName = iconName
        self.helper = helper
        self.isInvalid = isInvalid
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: iconName)
                    .foregroundStyle(isInvalid ? Color.red : Color.green)
                Text(title)
                    .font(.subheadline.weight(.semibold))
            }

            content
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
                .background(Color(uiColor: .secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(isInvalid ? Color.red.opacity(0.55) : Color.clear, lineWidth: 1.5)
                )

            if let helper {
                Text(helper)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct AuthPill: View {
    let title: String
    let tint: Color
    var foreground: Color = .white

    var body: some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(tint.opacity(0.16))
            .foregroundStyle(foreground)
            .clipShape(Capsule(style: .continuous))
    }
}

struct AuthBanner: View {
    let title: String
    let message: String
    let systemImage: String
    let tint: Color

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .foregroundStyle(tint)
                .font(.headline)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

struct AuthPrimaryButton: View {
    let title: String
    let systemImage: String
    let colors: [Color]
    var isLoading: Bool = false
    var isEnabled: Bool = true

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .tint(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            } else {
                Label(title, systemImage: systemImage)
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            }
        }
        .foregroundStyle(.white)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing)
                )
        )
        .opacity(isEnabled ? 1 : 0.5)
    }
}

struct AuthSecondaryButton: View {
    let title: String
    let systemImage: String
    let tint: Color

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.subheadline.weight(.semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .foregroundStyle(tint)
            .background(tint.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

struct AuthSocialButton: View {
    let title: String
    let systemImage: String
    let tint: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.headline)
                .foregroundStyle(tint)

            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color(uiColor: .separator).opacity(0.45), lineWidth: 1)
        )
    }
}

struct PasswordChecklistView: View {
    let checks: [PasswordCheck]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(checks) { check in
                HStack(spacing: 10) {
                    Image(systemName: check.isSatisfied ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(check.isSatisfied ? .green : .secondary)
                    Text(check.title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

@MainActor
private struct AuthComponentsPreviewContainer: View {
    var body: some View {
        ZStack {
            AuthBackgroundView()

            ScrollView {
                VStack(spacing: 20) {
                    AuthHeroCard(
                        iconName: "sparkles",
                        eyebrow: "Preview kit",
                        title: "Componenti auth",
                        subtitle: "Hero, card, banner e bottoni principali in una sola canvas.",
                        tint: .green,
                        trailingBadge: "Canvas"
                    )

                    AuthCard {
                        AuthSectionHeader(
                            title: "Campi e bottoni",
                            subtitle: "Base visiva per login e registrazione."
                        )

                        AuthFieldCard(
                            title: "Email",
                            iconName: "envelope.fill",
                            helper: "Helper text di esempio."
                        ) {
                            Text("paolo@example.com")
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        AuthPrimaryButton(
                            title: "Continua",
                            systemImage: "arrow.right.circle.fill",
                            colors: [.green, .mint],
                            isLoading: false,
                            isEnabled: true
                        )

                        AuthSecondaryButton(
                            title: "Azione secondaria",
                            systemImage: "wand.and.stars",
                            tint: .blue
                        )
                    }

                    AuthBanner(
                        title: "Messaggio di esempio",
                        message: "Questa anteprima ti aiuta a ritoccare spaziature e gerarchie senza lanciare una build completa.",
                        systemImage: "info.circle.fill",
                        tint: .orange
                    )
                }
                .padding(20)
            }
        }
    }
}

#Preview("Auth Components") {
    AuthComponentsPreviewContainer()
}
