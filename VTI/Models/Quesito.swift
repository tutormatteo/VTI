import Foundation

struct Quesito: Identifiable, Hashable {
    let id: UUID
    let materia: Materia
    let argomento: String
    let titolo: String
    let indice: Int
    let fileName: String
    let rawText: String
    let domandaLatex: String
    let opzioni: [String]
    let rispostaCorretta: Int?
    let urlFile: URL
    let latexBlock: String

    init(
        id: UUID = UUID(),
        materia: Materia,
        argomento: String,
        titolo: String,
        indice: Int,
        fileName: String,
        rawText: String,
        domandaLatex: String,
        opzioni: [String],
        rispostaCorretta: Int?,
        urlFile: URL,
        latexBlock: String
    ) {
        self.id = id
        self.materia = materia
        self.argomento = argomento
        self.titolo = titolo
        self.indice = indice
        self.fileName = fileName
        self.rawText = rawText
        self.domandaLatex = domandaLatex
        self.opzioni = opzioni
        self.rispostaCorretta = rispostaCorretta
        self.urlFile = urlFile
        self.latexBlock = latexBlock
    }
}

struct NewQuesitoDraft: Equatable {
    var materia: Materia = .matematica
    var argomento: String = ""
    var titolo: String = ""
    var testoDomanda: String = ""
    var opzioni: [String] = ["", "", "", "", ""]
    var rispostaCorretta: Int = 1
}

enum QuesitiInputMode: String, CaseIterable, Identifiable {
    case create = "Crea quesito"
    case importTxt = "Importa TXT"

    var id: String { rawValue }
}

enum TestSelectionMode: String, CaseIterable, Identifiable {
    case random = "Random"
    case manual = "Manuale"

    var id: String { rawValue }
}

struct ArgomentoGroupKey: Hashable, Identifiable {
    let materia: Materia
    let argomento: String

    var id: String { "\(materia.rawValue)|\(argomento)" }
}

enum EserciziarioScope: String, CaseIterable, Identifiable {
    case completo = "Completo"
    case materiaSingola = "Materia singola"

    var id: String { rawValue }
}

struct GeneratedDocument {
    let texURL: URL
    let pdfURL: URL?
    let log: String
}
