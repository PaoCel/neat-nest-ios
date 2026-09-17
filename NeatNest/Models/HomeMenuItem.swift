import SwiftUI

struct HomeMenuItem: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    let destination: AnyView
}
