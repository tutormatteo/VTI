import Foundation

struct QuesitoWriterService {
    let repositoryService: RepositoryService

    func save(draft: NewQuesitoDraft) throws -> URL {
        let materia = draft.materia
        let argomento = try sanitizedNameComponent(draft.argomento)
        let titolo = try sanitizedNameComponent(draft.titolo)
        let testoDomanda = draft.testoDomanda.trimmingCharacters(in: .whitespacesAndNewlines)
        let opzioni = draft.opzioni.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }

        guard !argomento.isEmpty, !titolo.isEmpty, !testoDomanda.isEmpty else {
            throw AppError.ioError("Completa materia, argomento, titolo e testo domanda.")
        }
        guard opzioni.count == 5, opzioni.allSatisfy({ !$0.isEmpty }) else {
            throw AppError.ioError("Il quesito deve avere esattamente 5 opzioni, tutte compilate.")
        }

        let fileURL = try buildOutputFileURL(materia: materia, argomento: argomento, titolo: titolo)
        let content = makeContent(question: testoDomanda, options: opzioni, correctAnswer: draft.rispostaCorretta)
        try content.write(to: fileURL, atomically: true, encoding: .utf8)
        return fileURL
    }

    func importTXT(
        sourceURL: URL,
        materia: Materia,
        argomento: String,
        titolo: String
    ) throws -> URL {
        let cleanedArgomento = try sanitizedNameComponent(argomento)
        let cleanedTitolo = try sanitizedNameComponent(titolo)
        guard !cleanedArgomento.isEmpty, !cleanedTitolo.isEmpty else {
            throw AppError.ioError("Inserisci materia, argomento e titolo per l'import.")
        }

        let raw = try String(contentsOf: sourceURL, encoding: .utf8)
        guard !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AppError.ioError("Il file TXT selezionato e vuoto.")
        }

        let fileURL = try buildOutputFileURL(materia: materia, argomento: cleanedArgomento, titolo: cleanedTitolo)
        try raw.write(to: fileURL, atomically: true, encoding: .utf8)
        return fileURL
    }

    func makeContent(question: String, options: [String], correctAnswer: Int) -> String {
        let optionLines = options
            .map { "    \\item \($0)" }
            .joined(separator: "\n")

        return """
        \\itemdomanda{\(question)}{
        \(optionLines)
        }

        Risposta Corretta: \(correctAnswer)
        """
    }

    /// Blocco `\itemdomanda`… come nel corpo dei test `.tex`, senza riga soluzione (stesso criterio del parser).
    func latexBlockForPreview(draft: NewQuesitoDraft) -> String? {
        let argomento = draft.argomento.trimmingCharacters(in: .whitespacesAndNewlines)
        let titolo = draft.titolo.trimmingCharacters(in: .whitespacesAndNewlines)
        let testoDomanda = draft.testoDomanda.trimmingCharacters(in: .whitespacesAndNewlines)
        let opzioni = draft.opzioni.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }

        guard !argomento.isEmpty, !titolo.isEmpty, !testoDomanda.isEmpty,
              opzioni.count == 5, opzioni.allSatisfy({ !$0.isEmpty }) else {
            return nil
        }

        let full = makeContent(question: testoDomanda, options: opzioni, correctAnswer: draft.rispostaCorretta)
        return stripRispostaLine(from: full)
    }

    private func stripRispostaLine(from text: String) -> String {
        text
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("Risposta Corretta:") }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func nextAvailableIndex(materia: Materia, argomento: String, titolo: String, folder: URL) throws -> Int {
        let prefix = "\(materia.rawValue) - \(argomento) - \(titolo) #"
        let files = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
        let matches = files
            .map(\.lastPathComponent)
            .filter { $0.hasPrefix(prefix) && $0.hasSuffix(".txt") }
            .compactMap { fileName -> Int? in
                let trimmed = fileName.replacingOccurrences(of: "\(prefix)", with: "").replacingOccurrences(of: ".txt", with: "")
                return Int(trimmed)
            }

        return (matches.max() ?? -1) + 1
    }

    private func buildOutputFileURL(materia: Materia, argomento: String, titolo: String) throws -> URL {
        let folder = try repositoryService.quesitiFolder(for: materia)
        let nextIndex = try nextAvailableIndex(materia: materia, argomento: argomento, titolo: titolo, folder: folder)
        let fileName = "\(materia.rawValue) - \(argomento) - \(titolo) #\(nextIndex).txt"
        return folder.appendingPathComponent(fileName)
    }

    private func sanitizedNameComponent(_ value: String) throws -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let invalid = CharacterSet(charactersIn: "/:\\?%*|\"<>")
        guard trimmed.rangeOfCharacter(from: invalid) == nil else {
            throw AppError.invalidFileNameComponent(value)
        }
        return trimmed.replacingOccurrences(of: "\n", with: " ")
    }
}
