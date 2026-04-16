import Foundation

/// Nome della materia come nel nome file (`Matematica - … #1.txt`) e come cartella `quesiti/Q - Matematica/`.
/// Può essere una delle materie predefinite o una aggiunta dall’utente.
struct Materia: Hashable, Identifiable, Codable, Comparable {
    let rawValue: String

    var id: String { rawValue }

    var repositoryFolderName: String {
        "Q - \(rawValue)"
    }

    var sectionTitle: String {
        rawValue
    }

    /// Crea una materia da un nome già validato (parser, disco).
    init(validatedRawValue: String) {
        self.rawValue = validatedRawValue
    }

    /// Valida il nome per file/cartella (stessi caratteri vietati dei segmenti argomento/titolo).
    init?(rawValue: String) {
        let t = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty, t.count <= 120 else { return nil }
        let invalid = CharacterSet(charactersIn: "/:\\?%*|\"<>\n\r")
        guard t.rangeOfCharacter(from: invalid) == nil else { return nil }
        self.rawValue = t
    }

    static let matematica = Materia(validatedRawValue: "Matematica")
    static let logica = Materia(validatedRawValue: "Logica")
    static let scienze = Materia(validatedRawValue: "Scienze")

    /// Cartelle create alla prima strutturazione del repository.
    static let defaultInstallMaterie: [Materia] = [.matematica, .logica, .scienze]

    static func < (lhs: Materia, rhs: Materia) -> Bool {
        lhs.rawValue.localizedStandardCompare(rhs.rawValue) == .orderedAscending
    }
}

enum SidebarSection: String, CaseIterable, Identifiable {
    case home = "Home"
    case quesitiRepository = "Repository quesiti"
    case quesitiPlus = "Quesiti+"
    case test = "Test"
    case eserciziario = "Eserciziario"

    var id: String { rawValue }

    /// Breve descrizione per la sidebar: aiuta a orientarsi senza aprire ogni sezione.
    var detailSubtitle: String {
        switch self {
        case .home:
            return "Cartella di lavoro e guida rapida"
        case .quesitiRepository:
            return "Sfoglia materie e anteprima PDF"
        case .quesitiPlus:
            return "Crea o importa nuovi quesiti"
        case .test:
            return "Estrai o scegli quesiti e genera PDF"
        case .eserciziario:
            return "Volume completo o per materia"
        }
    }
}
