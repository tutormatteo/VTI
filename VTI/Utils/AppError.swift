import Foundation

enum AppError: LocalizedError, Identifiable {
    case repositoryNotSelected
    case invalidRepository(URL)
    case malformedFileName(String)
    case malformedQuestionFile(URL)
    case templateNotFound(String)
    case pdflatexNotInstalled
    case pdfCompilationFailed(String)
    case invalidFileNameComponent(String)
    case ioError(String)

    var id: String { localizedDescription }

    var errorDescription: String? {
        switch self {
        case .repositoryNotSelected:
            return "Cartella di lavoro non selezionata. Sceglila dalla scheda Home."
        case .invalidRepository(let url):
            return "La cartella selezionata non e valida: \(url.path)"
        case .malformedFileName(let name):
            return "Il nome file non rispetta il formato atteso: \(name)"
        case .malformedQuestionFile(let url):
            return "Il file quesito non e leggibile o non contiene una domanda valida: \(url.lastPathComponent)"
        case .templateNotFound(let name):
            return "Template LaTeX non trovato: \(name)"
        case .pdflatexNotInstalled:
            return "pdflatex non e installato o non e raggiungibile. Installa MacTeX."
        case .pdfCompilationFailed(let output):
            return "Compilazione PDF fallita.\n\(output)"
        case .invalidFileNameComponent(let value):
            return "Il testo '\(value)' contiene caratteri non validi per il nome file."
        case .ioError(let message):
            return message
        }
    }
}

struct UserMessage: Identifiable, Equatable {
    enum Kind {
        case info
        case success
        case warning
        case error
    }

    let id = UUID()
    let kind: Kind
    let text: String
}

/// Esegue il blocco sul main queue nel ciclo successivo, così gli `@Published` non vengono
/// aggiornati durante il passaggio di layout SwiftUI (evita warning e crash su HSplitView).
enum ViewUpdateDefer {
    static func async(_ body: @escaping () -> Void) {
        DispatchQueue.main.async(execute: body)
    }
}
