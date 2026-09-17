import Foundation

protocol DemoReceiptProvider {
    func loadTemplates() async throws -> [DemoReceiptTemplate]
}
