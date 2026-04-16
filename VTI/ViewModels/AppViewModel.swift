import Foundation
import SwiftUI

@MainActor
final class AppViewModel: ObservableObject {
    @Published var selectedSection: SidebarSection = .home
    @Published var repositoryURL: URL?
    @Published var message: UserMessage?

    let repositoryService: RepositoryService
    let parserService: QuesitoParserService
    let writerService: QuesitoWriterService
    let latexService: LaTeXService
    let pdfCompilerService: PDFCompilerService
    let testGeneratorService: TestGeneratorService
    let eserciziarioGeneratorService: EserciziarioGeneratorService
    let testQuesitoUsageStore = TestQuesitoUsageStore()

    init() {
        let repositoryService = RepositoryService()
        let latexService = LaTeXService()
        let pdfCompilerService = PDFCompilerService()

        self.repositoryService = repositoryService
        self.parserService = QuesitoParserService()
        self.writerService = QuesitoWriterService(repositoryService: repositoryService)
        self.latexService = latexService
        self.pdfCompilerService = pdfCompilerService
        self.testGeneratorService = TestGeneratorService(
            repositoryService: repositoryService,
            latexService: latexService,
            pdfCompilerService: pdfCompilerService
        )
        self.eserciziarioGeneratorService = EserciziarioGeneratorService(
            repositoryService: repositoryService,
            latexService: latexService,
            pdfCompilerService: pdfCompilerService
        )
        self.repositoryURL = repositoryService.repositoryURL

        if repositoryURL != nil {
            try? repositoryService.ensureRepositoryStructure()
        }
    }

    func chooseRepository() {
        do {
            if let url = try repositoryService.chooseRepositoryFolder() {
                repositoryURL = url
                message = UserMessage(kind: .success, text: "Repository impostata in \(url.path)")
            }
        } catch {
            message = UserMessage(kind: .error, text: error.localizedDescription)
        }
    }

    func refreshRepositoryReference() {
        repositoryURL = repositoryService.repositoryURL
    }

    /// Crea `quesiti/Q - {nome}/` nel repository corrente.
    func addMateria(named: String) {
        do {
            _ = try repositoryService.addMateria(displayName: named)
            refreshRepositoryReference()
            message = UserMessage(kind: .success, text: "Materia aggiunta: cartella quesiti creata.")
        } catch {
            message = UserMessage(kind: .error, text: error.localizedDescription)
        }
    }
}
