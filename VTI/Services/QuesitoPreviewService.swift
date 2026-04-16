import Foundation

struct QuesitoPreviewService: Sendable {
    let latexService: LaTeXService
    let pdfCompilerService: PDFCompilerService

    /// Compila un singolo blocco quesito (come nel `BODY` del test) con il template di anteprima.
    func compilePDF(latexBody: String) throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("VTI-QuesitoPreview-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let texURL = dir.appendingPathComponent("QuesitoPreview.tex")
        _ = try latexService.writeRenderedTemplate(
            template: .quesitoPreview,
            placeholders: [
                "BODY": latexBody
            ],
            destinationURL: texURL
        )

        let result = try pdfCompilerService.compile(texURL: texURL)
        guard let pdf = result.pdfURL else {
            throw AppError.pdfCompilationFailed(result.log)
        }
        return pdf
    }
}
