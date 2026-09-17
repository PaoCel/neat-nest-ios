import Foundation

extension FormatStyle where Self == FloatingPointFormatStyle<Double>.Currency {
    /// Gli importi di NeatNest sono in euro.
    ///
    /// Formattarli a mano ("%.2f €") sbaglia in ogni locale che non sia quello
    /// italiano: cambia il separatore decimale, la posizione del simbolo e la
    /// spaziatura. Con `.currency(code:)` la valuta resta l'euro e cambia solo
    /// il modo di scriverla.
    static var euro: FloatingPointFormatStyle<Double>.Currency {
        .currency(code: "EUR")
    }
}
