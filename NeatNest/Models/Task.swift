import Foundation

struct Task: Identifiable {
    var id: String
    var title: String
    var assignedTo: String
    var createdBy: String
    var date: String
    var isConfirmed: Bool
}
