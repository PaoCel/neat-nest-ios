import Foundation

/// Mette insieme gli indizi di acquisto prima di disturbare l'utente.
///
/// Le due fonti sono cieche in modi opposti: Wallet sa quanto hai speso ma non
/// vede i contanti, la posizione vede tutto ma non sa gli importi. Quando
/// scattano entrambe per lo stesso acquisto, la notifica deve essere **una**,
/// con dentro il meglio di tutte e due. Due notifiche per una spesa sola sono
/// il modo più rapido per farsi disattivare.
struct PurchaseSignalCorrelator: Sendable {
    /// Entro quanto due segnali diversi parlano dello stesso acquisto.
    ///
    /// Largo di proposito: fra il pagamento alla cassa e l'uscita dal parcheggio
    /// passa tempo, e il geofence scatta con ritardo.
    let correlationWindow: TimeInterval
    /// Sotto questa distanza nel tempo, due segnali della stessa fonte sono la
    /// stessa cosa vista due volte.
    let duplicateWindow: TimeInterval

    init(correlationWindow: TimeInterval = 45 * 60, duplicateWindow: TimeInterval = 10 * 60) {
        self.correlationWindow = correlationWindow
        self.duplicateWindow = duplicateWindow
    }

    func prompts(from signals: [PurchaseSignal]) -> [PurchasePrompt] {
        var remaining = signals.sorted { $0.detectedAt < $1.detectedAt }
        var prompts: [PurchasePrompt] = []

        while !remaining.isEmpty {
            let signal = remaining.removeFirst()
            var group = [signal]

            // Prima si assorbono i doppioni della stessa fonte, poi si cerca la
            // conferma dell'altra.
            remaining.removeAll { candidate in
                guard isDuplicate(candidate, of: signal) else { return false }
                group.append(candidate)
                return true
            }

            if let matchIndex = remaining.firstIndex(where: { canCorrelate($0, with: signal) }) {
                group.append(remaining.remove(at: matchIndex))
            }

            prompts.append(makePrompt(from: group))
        }

        return prompts.sorted { $0.detectedAt > $1.detectedAt }
    }

    /// Due segnali diversi che raccontano lo stesso acquisto.
    func canCorrelate(_ candidate: PurchaseSignal, with signal: PurchaseSignal) -> Bool {
        guard candidate.source != signal.source else { return false }
        guard abs(candidate.detectedAt.timeIntervalSince(signal.detectedAt)) <= correlationWindow else { return false }

        // Se entrambi sanno da chi, devono essere d'accordo: pagare dal
        // benzinaio mentre si esce dal supermercato sono due cose distinte.
        if let a = candidate.retailerId, let b = signal.retailerId {
            return a == b
        }

        if let a = candidate.merchantName, let b = signal.merchantName {
            return Self.merchantsMatch(a, b)
        }

        // Uno dei due non sa da chi: il tempo basta a metterli insieme.
        return true
    }

    private func isDuplicate(_ candidate: PurchaseSignal, of signal: PurchaseSignal) -> Bool {
        candidate.source == signal.source
            && abs(candidate.detectedAt.timeIntervalSince(signal.detectedAt)) <= duplicateWindow
            && Self.merchantsMatch(candidate.merchantName, signal.merchantName)
    }

    /// "ESSELUNGA SPA" e "Esselunga Via Roma" sono lo stesso negozio.
    static func merchantsMatch(_ lhs: String?, _ rhs: String?) -> Bool {
        guard let lhs, let rhs else { return true }

        let left = Set(RecipeTextNormalizer.tokens(from: lhs))
        let right = Set(RecipeTextNormalizer.tokens(from: rhs))

        guard !left.isEmpty, !right.isEmpty else { return true }
        return !left.isDisjoint(with: right)
    }

    /// Costruisce la richiesta prendendo da ogni fonte quello che sa fare meglio.
    private func makePrompt(from group: [PurchaseSignal]) -> PurchasePrompt {
        let sorted = group.sorted { $0.detectedAt < $1.detectedAt }
        let sources = Set(sorted.map(\.source))

        // L'importo lo può dire solo Wallet.
        let amount = sorted.compactMap(\.amount).first

        // Il nome più informativo: quello agganciato a un punto vendita reale
        // batte quello grezzo del circuito di pagamento.
        let merchantName = sorted.first(where: { $0.retailerId != nil })?.merchantName
            ?? sorted.compactMap(\.merchantName).first

        return PurchasePrompt(
            id: sorted.map(\.id).sorted().joined(separator: "+"),
            signals: sorted,
            merchantName: merchantName,
            amount: amount,
            retailerId: sorted.compactMap(\.retailerId).first,
            detectedAt: sorted.last?.detectedAt ?? Date(),
            confidence: sources.count > 1 ? .confirmed : .likely
        )
    }
}
