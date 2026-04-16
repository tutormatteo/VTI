import Foundation

struct LaTeXService: Sendable {
    enum Template: String {
        case test = "TestTemplate"
        case eserciziario = "EserciziarioTemplate"
        /// Stesso preambolo del test: un solo blocco `\itemdomanda` nel corpo.
        case quesitoPreview = "QuesitoPreviewTemplate"
    }

    func render(template: Template, placeholders: [String: String]) throws -> String {
        let templateText = try loadTemplate(named: template.rawValue)
        return placeholders.reduce(templateText) { partial, item in
            partial.replacingOccurrences(of: "{{\(item.key)}}", with: item.value)
        }
    }

    func writeRenderedTemplate(
        template: Template,
        placeholders: [String: String],
        destinationURL: URL
    ) throws -> URL {
        let output = try render(template: template, placeholders: placeholders)
        try output.write(to: destinationURL, atomically: true, encoding: .utf8)
        return destinationURL
    }

    private func loadTemplate(named name: String) throws -> String {
        let bundle = Bundle.main
        if let url = bundle.url(forResource: name, withExtension: "tex", subdirectory: "Templates"),
           let content = try? String(contentsOf: url, encoding: .utf8) {
            return content
        }
        if let url = bundle.url(forResource: name, withExtension: "tex"),
           let content = try? String(contentsOf: url, encoding: .utf8) {
            return content
        }

        throw AppError.templateNotFound("\(name).tex")
    }
}
