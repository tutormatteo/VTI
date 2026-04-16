import Foundation

struct PDFCompilationResult: Sendable {
    let pdfURL: URL?
    let log: String
}

struct PDFCompilerService: Sendable {
    func compile(texURL: URL) throws -> PDFCompilationResult {
        let executable = try pdflatexExecutable()
        let outputDirectory = texURL.deletingLastPathComponent()
        let texFileName = texURL.lastPathComponent
        let firstRun = try runPdflatex(
            executable: executable,
            texFileName: texFileName,
            outputDirectory: outputDirectory
        )
        let secondRun = try runPdflatex(
            executable: executable,
            texFileName: texFileName,
            outputDirectory: outputDirectory
        )

        let log = firstRun + "\n\n----- SECOND PASS -----\n\n" + secondRun
        let pdfURL = outputDirectory.appendingPathComponent(texURL.deletingPathExtension().lastPathComponent).appendingPathExtension("pdf")

        guard FileManager.default.fileExists(atPath: pdfURL.path) else {
            throw AppError.pdfCompilationFailed(log)
        }

        return PDFCompilationResult(pdfURL: pdfURL, log: log)
    }

    func pdflatexExecutable() throws -> URL {
        let candidates = [
            "/Library/TeX/texbin/pdflatex",
            "/usr/texbin/pdflatex",
            "/opt/homebrew/bin/pdflatex",
            "/usr/local/bin/pdflatex"
        ]

        if let match = candidates.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) {
            return URL(fileURLWithPath: match)
        }

        throw AppError.pdflatexNotInstalled
    }

    private func runPdflatex(
        executable: URL,
        texFileName: String,
        outputDirectory: URL
    ) throws -> String {
        let process = Process()
        process.executableURL = executable
        process.currentDirectoryURL = outputDirectory
        process.arguments = [
            "-interaction=nonstopmode",
            "-halt-on-error",
            "-file-line-error",
            "-output-directory",
            outputDirectory.path,
            texFileName
        ]

        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = outputPipe

        try process.run()
        process.waitUntilExit()

        let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let log = String(data: data, encoding: .utf8) ?? "Nessun log disponibile."
        guard process.terminationStatus == 0 else {
            throw AppError.pdfCompilationFailed(log)
        }
        return log
    }
}
