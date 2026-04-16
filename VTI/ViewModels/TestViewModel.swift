import Foundation

@MainActor
final class TestViewModel: ObservableObject {
    private enum Defaults {
        static let excludeUsedKey = "VTI.excludeUsedQuesitiInTestRandom"
    }

    @Published var titoloTest = "Simulazione"
    @Published var dataTest: Date = Date()
    @Published var selectionMode: TestSelectionMode = .random
    @Published var manualSelection = Set<UUID>()
    @Published var randomRequests: [ArgomentoGroupKey: Int] = [:]
    @Published var expandedMaterie: Set<Materia> = []
    /// Ultima estrazione casuale (modalità Random); aggiornata da `setRandomRequest` / `estraiRandom`.
    @Published var randomExtractedQuesiti: [Quesito] = []
    @Published var generatedDocument: GeneratedDocument?
    @Published var message: UserMessage?
    @Published var isGenerating = false
    @Published var processingStatus = "Preparazione test..."

    /// Opzione facoltativa: se vero, nelle estrazioni casuali non compaiono quesiti già usati in test con PDF.
    @Published var excludeUsedFromRandomExtractions: Bool {
        didSet {
            UserDefaults.standard.set(excludeUsedFromRandomExtractions, forKey: Defaults.excludeUsedKey)
        }
    }

    private let generatorService: TestGeneratorService
    private let usageStore: TestQuesitoUsageStore

    init(generatorService: TestGeneratorService, usageStore: TestQuesitoUsageStore) {
        self.generatorService = generatorService
        self.usageStore = usageStore
        if UserDefaults.standard.object(forKey: Defaults.excludeUsedKey) != nil {
            self.excludeUsedFromRandomExtractions = UserDefaults.standard.bool(forKey: Defaults.excludeUsedKey)
        } else {
            // Prima installazione: esclusione disattivata; l’utente la attiva se la vuole.
            self.excludeUsedFromRandomExtractions = false
        }
    }

    /// Svuota lo storico dei file già usati (non annulla i PDF già creati).
    func clearTestUsageHistory() {
        usageStore.removeAll()
    }

    /// Ripristina selezione, output e messaggi per preparare un nuovo test.
    func clearForNewGeneration() {
        generatedDocument = nil
        message = nil
        manualSelection = []
        randomRequests = [:]
        randomExtractedQuesiti = []
        titoloTest = "Simulazione"
        dataTest = Date()
    }

    func toggleSelection(for quesito: Quesito) {
        if manualSelection.contains(quesito.id) {
            manualSelection.remove(quesito.id)
        } else {
            manualSelection.insert(quesito.id)
        }
    }

    func availableGroups(from quesiti: [Quesito]) -> [Materia: [String: [Quesito]]] {
        let byMateria = Dictionary(grouping: quesiti, by: \.materia)
        return byMateria.mapValues { items in
            Dictionary(grouping: items, by: \.argomento)
        }
    }

    /// Quanti quesiti sono disponibili per l’estrazione (rispettando l’esclusione “già usati” se attiva).
    func eligibleCount(for key: ArgomentoGroupKey, allQuesiti: [Quesito]) -> Int {
        let matching = allQuesiti.filter { $0.materia == key.materia && $0.argomento == key.argomento }
        guard excludeUsedFromRandomExtractions else {
            return matching.count
        }
        return matching.filter { !usageStore.contains($0.fileName) }.count
    }

    func setRandomRequest(for key: ArgomentoGroupKey, value: Int, allQuesiti: [Quesito]) {
        let maxVal = eligibleCount(for: key, allQuesiti: allQuesiti)
        randomRequests[key] = max(0, min(value, maxVal))
        recomputeRandomExtracted(from: allQuesiti)
    }

    func requestedCount(for key: ArgomentoGroupKey) -> Int {
        randomRequests[key] ?? 0
    }

    /// Allinea le quantità richieste se il massimo elegibile è sceso (es. dopo aver attivato l’esclusione).
    func clampRandomRequestsToEligible(allQuesiti: [Quesito]) {
        for (key, count) in randomRequests where count > 0 {
            let maxVal = eligibleCount(for: key, allQuesiti: allQuesiti)
            if count > maxVal {
                randomRequests[key] = maxVal
            }
        }
    }

    /// Nuova estrazione casuale con le quantità già impostate.
    func estraiRandom(from allQuesiti: [Quesito]) {
        recomputeRandomExtracted(from: allQuesiti)
    }

    private func recomputeRandomExtracted(from allQuesiti: [Quesito]) {
        var selection: [Quesito] = []
        for (key, count) in randomRequests where count > 0 {
            let matching = allQuesiti.filter { $0.materia == key.materia && $0.argomento == key.argomento }
            let pool: [Quesito]
            if excludeUsedFromRandomExtractions {
                pool = matching.filter { !usageStore.contains($0.fileName) }
            } else {
                pool = matching
            }
            selection.append(contentsOf: pool.shuffled().prefix(count))
        }
        randomExtractedQuesiti = selection.sorted {
            if $0.materia != $1.materia { return $0.materia.rawValue < $1.materia.rawValue }
            if $0.argomento != $1.argomento { return $0.argomento < $1.argomento }
            return $0.fileName < $1.fileName
        }
    }

    func summaryByMateria() -> [Materia: Int] {
        Dictionary(grouping: randomRequests, by: \.key.materia).mapValues { entries in
            entries.map(\.value).reduce(0, +)
        }
    }

    func selectedQuesiti(from allQuesiti: [Quesito]) -> [Quesito] {
        switch selectionMode {
        case .manual:
            return allQuesiti
                .filter { manualSelection.contains($0.id) }
                .sorted { $0.fileName < $1.fileName }
        case .random:
            return randomExtractedQuesiti
        }
    }

    func generate(from allQuesiti: [Quesito]) {
        let quesiti = selectedQuesiti(from: allQuesiti)
        guard !quesiti.isEmpty else {
            message = UserMessage(kind: .warning, text: "Seleziona almeno un quesito.")
            return
        }
        isGenerating = true
        processingStatus = "Generazione TEX in corso..."
        let title = titoloTest
        let date = dataTest
        let service = generatorService
        let fileNamesUsed = quesiti.map(\.fileName)

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            do {
                let document = try service.generate(title: title, date: date, quesiti: quesiti)
                DispatchQueue.main.async {
                    self?.generatedDocument = document
                    self?.isGenerating = false
                    if document.pdfURL != nil {
                        self?.usageStore.markUsed(fileNames: fileNamesUsed)
                        self?.message = UserMessage(kind: .success, text: "Test generato e PDF compilato correttamente.")
                    } else {
                        self?.message = UserMessage(kind: .warning, text: "TEX generato, ma il PDF non e stato compilato. Controlla il log.")
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self?.isGenerating = false
                    self?.message = UserMessage(kind: .error, text: error.localizedDescription)
                }
            }
        }
    }
}
