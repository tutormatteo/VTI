import Foundation

struct TestGeneratorService: Sendable {
    let repositoryService: RepositoryService
    let latexService: LaTeXService
    let pdfCompilerService: PDFCompilerService

    func generate(
        title: String,
        date: Date,
        quesiti: [Quesito]
    ) throws -> GeneratedDocument {
        let destinationFolder = try repositoryService.testFolder()
        let timestamp = Self.timestampFormatter.string(from: Date())
        let safeTitle = sanitizedSegment(title.isEmpty ? "Test" : title)
        let dateString = Self.fileDateFormatter.string(from: date)
        let safeDate = sanitizedSegment(dateString)
        let fileName = "Test_\(safeTitle)_\(safeDate)_\(timestamp)"
        let texURL = destinationFolder.appendingPathComponent(fileName).appendingPathExtension("tex")

        let body = quesiti.map(\.latexBlock).joined(separator: "\n\n")
        _ = try latexService.writeRenderedTemplate(
            template: .test,
            placeholders: [
                "TITLE": title.isEmpty ? "Test personalizzato" : title,
                "DATE": Self.displayDateFormatter.string(from: date),
                "BODY": body
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
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "_")
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: "_")
    }

    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return formatter
    }()

    private static let fileDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static let displayDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.locale = Locale(identifier: "it_IT")
        return formatter
    }()
}
