import SwiftUI

struct FeaturePlaceholderView: View {
    let featureName: String

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "hammer.circle")
                .font(.system(size: 56))
                .foregroundColor(.orange)

            Text("\(featureName) in arrivo")
                .font(.title2)
                .fontWeight(.bold)

            Text("Per questa build abbiamo reso stabile il flusso budget. Le altre aree verranno migrate allo stesso backend nei prossimi passaggi.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)
        }
        .padding()
        .navigationTitle(featureName)
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
    }
}

#Preview("Feature Placeholder") {
    NavigationStack {
        FeaturePlaceholderView(featureName: "Dispensa")
    }
}
