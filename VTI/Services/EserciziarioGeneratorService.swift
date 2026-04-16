import Foundation

struct EserciziarioGeneratorService: Sendable {
    let repositoryService: RepositoryService
    let latexService: LaTeXService
    let pdfCompilerService: PDFCompilerService

    func generate(scope: EserciziarioScope, materia: Materia?, quesiti: [Quesito]) throws -> GeneratedDocument {
        let destinationFolder = try repositoryService.eserciziarioFolder()
        let timestamp = Self.timestampFormatter.string(from: Date())
        let dateString = Self.dateFormatter.string(from: Date())
        let volumeName = scope == .completo ? "Completo" : (materia?.rawValue ?? "Materia")
        let texURL = destinationFolder
            .appendingPathComponent("Eserciziario_\(sanitizedSegment(volumeName))_\(dateString)_\(timestamp)")
            .appendingPathExtension("tex")

        let filtered = scope == .completo ? quesiti : quesiti.filter { $0.materia == materia }
        let grouped = Dictionary(grouping: filtered, by: \.materia)
        let orderedMaterie: [Materia] = scope == .completo
            ? grouped.keys.sorted()
            : [materia].compactMap { $0 }
        let content = orderedMaterie.compactMap { materia -> String? in
            guard let items = grouped[materia], !items.isEmpty else { return nil }
            let body = items.map(\.latexBlock).joined(separator: "\n\n")
            return "\\section{\(materia.sectionTitle)}\n\\begin{enumerate}[leftmargin=*]\n\(body)\n\\end{enumerate}"
        }.joined(separator: "\n\n")

        let solutions = orderedMaterie.compactMap { materia -> String? in
            guard let items = grouped[materia], !items.isEmpty else { return nil }
            let rows = items.enumerated().map { offset, item in
                let answer = item.rispostaCorretta.map(String.init) ?? "-"
                return "\\item [\(materia.rawValue)] Domanda \(offset + 1): \(answer)"
            }.joined(separator: "\n")
            return "\\section*{Soluzioni \(materia.rawValue)}\n\\begin{itemize}[leftmargin=*]\n\(rows)\n\\end{itemize}"
        }.joined(separator: "\n\n")

        _ = try latexService.writeRenderedTemplate(
            template: .eserciziario,
            placeholders: [
                "HEADER_TITLE": "Eserciziario",
                "VOLUME_TITLE": volumeName,
                "ACADEMIC_YEAR": "A.A. 2025 -- 2026",
                "CONTENT": content,
                "SOLUTIONS": solutions
            ],
            destinationURL: texURL
        )

        do {
            let pdf = try pdfCompilerService.compile(texURL: texURL)
            return GeneratedDocument(texURL: texURL, pdfURL: pdf.pdfURL, log: pdf.log)
        } catch let error as AppError {
            return GeneratedDocument(texURL: texURL, pdfURL: nil, log: error.localizedDescription)
        }
    }

    private func sanitizedSegment(_ value: String) -> String {
        value.replacingOccurrences(of: " ", with: "_")
    }

    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HHmmss"
        return formatter
    }()

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}
