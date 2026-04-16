import Foundation

@MainActor
final class EserciziarioViewModel: ObservableObject {
    @Published var scope: EserciziarioScope = .completo
    @Published var materia: Materia = .matematica
    @Published var generatedDocument: GeneratedDocument?
    @Published var message: UserMessage?
    @Published var isGenerating = false
    @Published var processingStatus = "Preparazione eserciziario..."

    private let generatorService: EserciziarioGeneratorService

    init(generatorService: EserciziarioGeneratorService) {
        self.generatorService = generatorService
    }

    /// Allinea la materia scelta se l’elenco cartelle è cambiato.
    func syncMateriaSelection(available: [Materia]) {
        guard !available.isEmpty else { return }
        if !available.contains(materia) {
            materia = available[0]
        }
    }

    func generate(from quesiti: [Quesito]) {
        guard !quesiti.isEmpty else {
            message = UserMessage(kind: .warning, text: "Nessun quesito disponibile per questa selezione.")
            return
        }
        isGenerating = true
        processingStatus = "Generazione eserciziario in corso..."
        let service = generatorService
        let scope = self.scope
        let materia = self.materia

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            do {
                let document = try service.generate(
                    scope: scope,
                    materia: scope == .completo ? nil : materia,
                    quesiti: quesiti
                )
                DispatchQueue.main.async {
                    self?.generatedDocument = document
                    self?.isGenerating = false
                    if document.pdfURL != nil {
                        self?.message = UserMessage(kind: .success, text: "Eserciziario generato e PDF compilato.")
                    } else {
                        self?.message = UserMessage(kind: .warning, text: "Eserciziario TEX creato, ma PDF non compilato. Controlla il log.")
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
