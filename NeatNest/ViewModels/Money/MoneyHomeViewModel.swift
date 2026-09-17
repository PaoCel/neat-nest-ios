import Foundation
import FirebaseFirestore
import Observation

/// Periodo su cui si guarda il saldo.
enum MoneyPeriod: String, CaseIterable, Identifiable, Hashable {
    case month
    case year
    case all

    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .month:
            return "Mese"
        case .year:
            return "Anno"
        case .all:
            return "Tutto"
        }
    }

    /// Data a partire dalla quale i movimenti contano. `nil` = da sempre.
    func startDate(from reference: Date, calendar: Calendar = .current) -> Date? {
        switch self {
        case .month:
            return calendar.dateInterval(of: .month, for: reference)?.start
        case .year:
            return calendar.dateInterval(of: .year, for: reference)?.start
        case .all:
            return nil
        }
    }
}

@MainActor
@Observable
final class MoneyHomeViewModel {
    private(set) var entries: [MoneyEntry] = []
    private(set) var isLoading = false
    var errorMessage: String?

    var period: MoneyPeriod = .month
    var kindFilter: MoneyEntry.Kind?

    private let userId: String
    private let repository: MoneyRepository

    @ObservationIgnored
    private nonisolated(unsafe) var listener: ListenerRegistration?

    init(userId: String, repository: MoneyRepository = MoneyRepository()) {
        self.userId = userId
        self.repository = repository
    }

    deinit {
        listener?.remove()
    }

    func start() {
        guard listener == nil else { return }

        isLoading = true
        errorMessage = nil

        listener = repository.observeEntries(for: userId) { [weak self] result in
            _Concurrency.Task { @MainActor [weak self] in
                guard let self else { return }

                self.isLoading = false

                switch result {
                case .success(let entries):
                    self.entries = entries
                    self.errorMessage = nil
                case .failure:
                    self.errorMessage = MoneyError.persistenceFailed.errorDescription
                }
            }
        }
    }

    func retry() {
        listener?.remove()
        listener = nil
        start()
    }

    // MARK: - Derivati

    var periodEntries: [MoneyEntry] {
        guard let start = period.startDate(from: Date()) else { return entries }
        return entries.filter { $0.date >= start }
    }

    var balance: MoneyBalance {
        MoneyBalance(entries: periodEntries)
    }

    var visibleEntries: [MoneyEntry] {
        guard let kindFilter else { return periodEntries }
        return periodEntries.filter { $0.kind == kindFilter }
    }

    /// Movimenti raggruppati per giorno, dal più recente.
    var entriesByDay: [(day: Date, entries: [MoneyEntry])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: visibleEntries) { calendar.startOfDay(for: $0.date) }

        return grouped
            .sorted { $0.key > $1.key }
            .map { (day: $0.key, entries: $0.value.sorted { $0.date > $1.date }) }
    }

    var isEmpty: Bool {
        entries.isEmpty && !isLoading
    }

    // MARK: - Azioni

    func add(kind: MoneyEntry.Kind, amount: Double, note: String, date: Date) async {
        guard amount > 0 else {
            errorMessage = MoneyError.invalidAmount.errorDescription
            return
        }

        let entry = MoneyEntry(
            userId: userId,
            kind: kind,
            amount: amount,
            note: note.trimmed,
            date: date
        )

        await perform { try await self.repository.save(entry) }
    }

    func delete(_ entry: MoneyEntry) async {
        await perform { try await self.repository.delete(entryId: entry.id) }
    }

    private func perform(_ work: @escaping () async throws -> Void) async {
        errorMessage = nil

        do {
            try await work()
        } catch let error as MoneyError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = MoneyError.persistenceFailed.errorDescription
        }
    }
}
