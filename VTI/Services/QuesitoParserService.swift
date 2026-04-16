import Foundation

struct QuesitoParserService {
    func parseFile(at url: URL) throws -> Quesito {
        let fileName = url.lastPathComponent
        let metadata = try parseFileName(fileName)
        let rawText = try String(contentsOf: url, encoding: .utf8)
        let latexBlock = stripSolutionLine(from: rawText)
        let domandaLatex = extractDomanda(from: rawText) ?? ""
        let opzioni = extractOptions(from: rawText)
        let rispostaCorretta = extractCorrectAnswer(from: rawText)

        guard !latexBlock.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AppError.malformedQuestionFile(url)
        }

        return Quesito(
            materia: metadata.materia,
            argomento: metadata.argomento,
            titolo: metadata.titolo,
            indice: metadata.indice,
            fileName: fileName,
            rawText: rawText,
            domandaLatex: domandaLatex,
            opzioni: opzioni,
            rispostaCorretta: rispostaCorretta,
            urlFile: url,
            latexBlock: latexBlock
        )
    }

    func parseFileName(_ fileName: String) throws -> (materia: Materia, argomento: String, titolo: String, indice: Int) {
        let pattern = #"^(.+?) - (.+?) - (.+?) #(\d+)\.txt$"#
        let regex = try NSRegularExpression(pattern: pattern)
        let range = NSRange(fileName.startIndex..<fileName.endIndex, in: fileName)
        guard let match = regex.firstMatch(in: fileName, range: range), match.numberOfRanges == 5 else {
            throw AppError.malformedFileName(fileName)
        }

        func value(at index: Int) -> String {
            let nsRange = match.range(at: index)
            guard let range = Range(nsRange, in: fileName) else { return "" }
            return String(fileName[range])
        }

        guard let materia = Materia(rawValue: value(at: 1)) else {
            throw AppError.malformedFileName(fileName)
        }

        return (materia, value(at: 2), value(at: 3), Int(value(at: 4)) ?? 0)
    }

    private func extractCorrectAnswer(from text: String) -> Int? {
        let pattern = #"Risposta\s+Corretta:\s*(\d+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, range: range), let numberRange = Range(match.range(at: 1), in: text) else {
            return nil
        }
        return Int(text[numberRange])
    }

    private func stripSolutionLine(from text: String) -> String {
        text
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("Risposta Corretta:") }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func extractDomanda(from text: String) -> String? {
        guard let start = text.range(of: #"\\itemdomanda{"#, options: .regularExpression) else {
            return nil
        }

        let firstOpen = text.index(before: start.upperBound)
        guard let first = extractBraceContent(in: text, from: firstOpen) else {
            return nil
        }
        return first.content.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func extractOptions(from text: String) -> [String] {
        guard let start = text.range(of: #"\\itemdomanda{"#, options: .regularExpression) else {
            return []
        }

        let firstOpen = text.index(before: start.upperBound)
        guard let first = extractBraceContent(in: text, from: firstOpen),
              let second = extractBraceContent(in: text, from: first.nextIndex) else {
            return []
        }

        return second.content
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.hasPrefix("\\item") }
            .map { $0.replacingOccurrences(of: "\\item", with: "").trimmingCharacters(in: .whitespacesAndNewlines) }
    }

    private func extractBraceContent(in text: String, from startIndex: String.Index) -> (content: String, nextIndex: String.Index)? {
        guard startIndex <= text.endIndex else { return nil }

        var cursor = startIndex
        guard cursor < text.endIndex, text[cursor] == "{" else { return nil }

        var depth = 0
        let contentStart = text.index(after: cursor)
        while cursor < text.endIndex {
            let character = text[cursor]
            if character == "{" {
                depth += 1
            } else if character == "}" {
                depth -= 1
                if depth == 0 {
                    let content = String(text[contentStart..<cursor])
                    let nextIndex = text.index(after: cursor)
                    return (content, nextIndex)
                }
            }
            cursor = text.index(after: cursor)
        }

        return nil
    }
}
