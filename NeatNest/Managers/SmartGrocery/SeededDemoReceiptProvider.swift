import Foundation

struct SeededDemoReceiptProvider: DemoReceiptProvider {
    func loadTemplates() async throws -> [DemoReceiptTemplate] {
        let calendar = Calendar.current
        let now = Date()

        return [
            DemoReceiptTemplate(
                id: "esselunga-settimanale",
                title: "Spesa settimanale",
                retailerName: "Esselunga",
                purchaseDate: calendar.date(byAdding: .day, value: -2, to: now) ?? now,
                currency: "EUR",
                lineItems: [
                    DemoReceiptTemplateLine(rawLineText: "latte Arborea", quantity: 2, unitPrice: 1.89, lineTotal: 3.78),
                    DemoReceiptTemplateLine(rawLineText: "yogurt greco", quantity: 2, unitPrice: 1.79, lineTotal: 3.58),
                    DemoReceiptTemplateLine(rawLineText: "petto di pollo", quantity: 1, unitPrice: 6.49, lineTotal: 6.49),
                    DemoReceiptTemplateLine(rawLineText: "zucchine", quantity: 1, unitPrice: 2.36, lineTotal: 2.36),
                    DemoReceiptTemplateLine(rawLineText: "pasta Barilla", quantity: 2, unitPrice: 1.39, lineTotal: 2.78),
                    DemoReceiptTemplateLine(rawLineText: "Monopoly", quantity: 1, unitPrice: 24.90, lineTotal: 24.90)
                ],
                accentColorName: "green"
            ),
            DemoReceiptTemplate(
                id: "lidl-smart",
                title: "Spesa smart",
                retailerName: "Lidl",
                purchaseDate: calendar.date(byAdding: .day, value: -7, to: now) ?? now,
                currency: "EUR",
                lineItems: [
                    DemoReceiptTemplateLine(rawLineText: "uova", quantity: 1, unitPrice: 2.29, lineTotal: 2.29),
                    DemoReceiptTemplateLine(rawLineText: "riso basmati", quantity: 1, unitPrice: 2.49, lineTotal: 2.49),
                    DemoReceiptTemplateLine(rawLineText: "tonno all'olio", quantity: 2, unitPrice: 2.15, lineTotal: 4.30),
                    DemoReceiptTemplateLine(rawLineText: "pane", quantity: 1, unitPrice: 1.59, lineTotal: 1.59),
                    DemoReceiptTemplateLine(rawLineText: "acqua naturale 6x1.5L", quantity: 1, unitPrice: 2.39, lineTotal: 2.39),
                    DemoReceiptTemplateLine(rawLineText: "detersivo piatti", quantity: 1, unitPrice: 2.79, lineTotal: 2.79)
                ],
                accentColorName: "blue"
            ),
            DemoReceiptTemplate(
                id: "conad-cena-veloce",
                title: "Cena veloce",
                retailerName: "Conad",
                purchaseDate: calendar.date(byAdding: .day, value: -15, to: now) ?? now,
                currency: "EUR",
                lineItems: [
                    DemoReceiptTemplateLine(rawLineText: "latte senza lattosio", quantity: 1, unitPrice: 2.09, lineTotal: 2.09),
                    DemoReceiptTemplateLine(rawLineText: "pane", quantity: 1, unitPrice: 1.89, lineTotal: 1.89),
                    DemoReceiptTemplateLine(rawLineText: "zucchine", quantity: 1, unitPrice: 2.10, lineTotal: 2.10),
                    DemoReceiptTemplateLine(rawLineText: "uova", quantity: 1, unitPrice: 2.69, lineTotal: 2.69),
                    DemoReceiptTemplateLine(rawLineText: "succo ACE", quantity: 1, unitPrice: 2.49, lineTotal: 2.49),
                    DemoReceiptTemplateLine(rawLineText: "sacchetti pattumiera", quantity: 1, unitPrice: 3.29, lineTotal: 3.29)
                ],
                accentColorName: "orange"
            )
        ]
    }
}
