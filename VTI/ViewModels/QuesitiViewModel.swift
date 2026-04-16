import AppKit
import Foundation
import UniformTypeIdentifiers

@MainActor
final class QuesitiViewModel: ObservableObject {
    @Published var quesiti: [Quesito] = []
    @Published var selectedQuesito: Quesito?
    @Published var draft = NewQuesitoDraft()
    @Published var selectedMateria: Materia?
    @Published var argomentoFilter = ""
    @Published var isLoading = false
    @Published var message: UserMessage?
    @Published var inputMode: QuesitiInputMode = .create
    @Published var importMateria: Materia = .matematica
    /// Elenco materie dalle cartelle `quesiti/Q - …` (aggiornato a ogni caricamento).
    @Published var materieOrdered: [Materia] = Materia.defaultInstallMaterie
    @Published var importArgomento = ""
    @Published var importTitolo = ""
    @Published var importFileURL: URL?
    @Published var expandedMaterie: Set<Materia> = []
    @Published var expandedArgomenti: Set<String> = []

    @Published var previewPDFURL: URL?
    @Published var previewLoading = false
    @Published var previewError: String?

    private let repositoryService: RepositoryService
    private let parserService: QuesitoParserService
    private let writerService: QuesitoWriterService
    private let previewService: QuesitoPreviewService
    private var previewTask: Task<Void, Never>?

    init(
        repositoryService: RepositoryService,
        parserService: QuesitoParserService,
        writerService: QuesitoWriterService,
        previewService: QuesitoPreviewService
    ) {
        self.repositoryService = repositoryService
        self.parserService = parserService
        self.writerService = writerService
        self.previewService = previewService
    }

    var filteredQuesiti: [Quesito] {
        quesiti.filter { quesito in
            let materiaMatch = selectedMateria == nil || quesito.materia == selectedMateria
            let argomentoMatch = argomentoFilter.isEmpty || quesito.argomento.localizedCaseInsensitiveContains(argomentoFilter)
            return materiaMatch && argomentoMatch
        }.sorted {
            if $0.materia != $1.materia { return $0.materia.rawValue < $1.materia.rawValue }
            if $0.argomento != $1.argomento { return $0.argomento < $1.argomento }
            return $0.fileName < $1.fileName
        }
    }

    var groupedQuesiti: [Materia: [String: [Quesito]]] {
        let groupedByMateria = Dictionary(grouping: quesiti, by: \.materia)
        return groupedByMateria.mapValues { items in
            let byArgomento = Dictionary(grouping: items, by: \.argomento)
            return byArgomento.mapValues { $0.sorted { $0.fileName < $1.fileName } }
        }
    }

    var groupedCounts: [Materia: [String: Int]] {
        let groupedByMateria = Dictionary(grouping: quesiti, by: \.materia)
        return groupedByMateria.mapValues { items in
            Dictionary(grouping: items, by: \.argomento)
                .mapValues(\.count)
        }
    }

    func loadQuesiti() {
        isLoading = true
        defer { isLoading = false }

        do {
            try repositoryService.ensureRepositoryStructure()
            materieOrdered = try repositoryService.listMaterie()
            expandedMaterie.formUnion(Set(materieOrdered))
            clampMateriaSelections()
            quesiti = try repositoryService.allQuestionFiles().compactMap { try? parserService.parseFile(at: $0) }
            if selectedQuesito == nil {
                selectedQuesito = quesiti.first
            }
            // Evita che resti visibile un errore vecchio (es. cartella non selezionata) dopo un caricamento riuscito.
            if message?.kind == .error {
                message = nil
            }
        } catch {
            quesiti = []
            materieOrdered = []
            message = UserMessage(kind: .error, text: error.localizedDescription)
        }
    }

    func saveDraft() {
        do {
            let url = try writerService.save(draft: draft)
            message = UserMessage(kind: .success, text: "Quesito salvato: \(url.lastPathComponent)")
            draft = NewQuesitoDraft()
            loadQuesiti()
        } catch {
            message = UserMessage(kind: .error, text: error.localizedDescription)
        }
    }

    private func clampMateriaSelections() {
        guard !materieOrdered.isEmpty else { return }
        if !materieOrdered.contains(draft.materia) {
            draft.materia = materieOrdered[0]
        }
        if !materieOrdered.contains(importMateria) {
            importMateria = materieOrdered[0]
        }
    }

    func addOption() {
        draft.opzioni.append("")
    }

    func removeOption(at index: Int) {
        guard draft.opzioni.count > 2 else { return }
        draft.opzioni.remove(at: index)
        draft.rispostaCorretta = min(draft.rispostaCorretta, draft.opzioni.count)
    }

    func pickImportTXTFile() {
        let panel = NSOpenPanel()
        panel.title = "Seleziona file TXT del quesito"
        panel.allowedContentTypes = [.plainText]
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false

        if panel.runModal() == .OK {
            importFileURL = panel.url
        }
    }

    func importTXT() {
        guard let sourceURL = importFileURL else {
            message = UserMessage(kind: .warning, text: "Seleziona prima un file TXT da importare.")
            return
        }

        do {
            let saved = try writerService.importTXT(
                sourceURL: sourceURL,
                materia: importMateria,
                argomento: importArgomento,
                titolo: importTitolo
            )
            message = UserMessage(kind: .success, text: "Import completato: \(saved.lastPathComponent)")
            importArgomento = ""
            importTitolo = ""
            importFileURL = nil
            loadQuesiti()
        } catch {
            message = UserMessage(kind: .error, text: error.localizedDescription)
        }
    }

    func totalCount(for materia: Materia) -> Int {
        groupedCounts[materia]?.values.reduce(0, +) ?? 0
    }

    func argomentoKey(materia: Materia, argomento: String) -> String {
        "\(materia.rawValue)|\(argomento)"
    }

    /// Ripristina bozza creazione, campi import e anteprima PDF nella tab Quesiti+.
    func clearQuesitiPlusForm() {
        draft = NewQuesitoDraft()
        draft.materia = materieOrdered.first ?? .matematica
        importMateria = materieOrdered.first ?? .matematica
        importArgomento = ""
        importTitolo = ""
        importFileURL = nil
        inputMode = .create
        message = nil
        clearPreview()
    }

    // MARK: - Anteprima PDF (pdflatex)

    func clearPreview() {
        previewTask?.cancel()
        previewPDFURL = nil
        previewError = nil
        previewLoading = false
    }

    func scheduleDraftPreviewDebounced() {
        previewTask?.cancel()
        guard writerService.latexBlockForPreview(draft: draft) != nil else {
            previewPDFURL = nil
            previewError = nil
            previewLoading = false
            return
        }
        previewTask = Task {
            try? await Task.sleep(nanoseconds: 550_000_000)
            guard !Task.isCancelled else { return }
            guard let block = writerService.latexBlockForPreview(draft: draft) else { return }
            await runPreviewAsync(latexBlock: block)
        }
    }

    func runDraftPreviewImmediately() {
        previewTask?.cancel()
        guard let block = writerService.latexBlockForPreview(draft: draft) else {
            previewPDFURL = nil
            previewError = "Compila argomento, titolo, testo domanda e tutte e 5 le opzioni per generare l'anteprima."
            previewLoading = false
            return
        }
        Task { await runPreviewAsync(latexBlock: block) }
    }

    func refreshPreviewForSelectedQuesito() {
        previewTask?.cancel()
        guard let quesito = selectedQuesito else {
            previewPDFURL = nil
            previewError = nil
            previewLoading = false
            return
        }
        Task { await runPreviewAsync(latexBlock: quesito.latexBlock) }
    }

    private func runPreviewAsync(latexBlock: String) async {
        previewLoading = true
        previewError = nil
        defer { previewLoading = false }

        do {
            let url = try await Task.detached { [previewService] in
                try previewService.compilePDF(latexBody: latexBlock)
            }.value
            previewPDFURL = url
        } catch {
            previewPDFURL = nil
            previewError = error.localizedDescription
        }
    }

    func exportPreviewPNG(suggestedFileName: String) {
        guard let pdfURL = previewPDFURL else {
            message = UserMessage(kind: .warning, text: "Genera prima l'anteprima PDF.")
            return
        }
        do {
            let data = try QuesitoPreviewPNGExporter.pngData(from: pdfURL)
            let panel = NSSavePanel()
            panel.allowedContentTypes = [UTType.png]
            panel.nameFieldStringValue = suggestedFileName
            panel.canCreateDirectories = true
            guard panel.runModal() == .OK, let dest = panel.url else { return }
            try data.write(to: dest, options: .atomic)
            message = UserMessage(kind: .success, text: "PNG salvato: \(dest.lastPathComponent)")
        } catch {
            message = UserMessage(kind: .error, text: error.localizedDescription)
        }
    }
}
