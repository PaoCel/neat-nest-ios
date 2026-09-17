import SwiftUI

struct HeaderView: View {
    var month: String
    var isExpanded: Bool
    var toggleExpansion: () -> Void

    var body: some View {
        HStack {
            Text(month)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.blue)

            Spacer()

            Button(action: {
                toggleExpansion()
            }) {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .foregroundColor(.blue)
                    .padding()
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            toggleExpansion()
        }
    }
}
