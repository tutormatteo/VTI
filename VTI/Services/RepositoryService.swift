import AppKit
import Foundation

final class RepositoryService: @unchecked Sendable {
    private let fileManager = FileManager.default
    private let defaultsKey = "repositoryBookmark"
    /// Percorso testuale di backup: se il bookmark non si risolve (es. opzioni diverse con/ senza sandbox), la cartella resta comunque ritrovabile.
    private let pathKey = "repositoryPath"

    private(set) var repositoryURL: URL?

    init() {
        repositoryURL = resolveBookmark()
    }

    func chooseRepositoryFolder() throws -> URL? {
        let panel = NSOpenPanel()
        panel.prompt = "Seleziona"
        panel.message = "Seleziona la cartella di lavoro (quesiti, test, eserciziario)."
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false

        guard panel.runModal() == .OK, let url = panel.url else {
            return nil
        }

        try setRepository(url)
        return url
    }

    func setRepository(_ url: URL) throws {
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw AppError.invalidRepository(url)
        }

        repositoryURL = url
        try persistBookmark(for: url)
        try ensureRepositoryStructure()
    }

    func ensureRepositoryStructure() throws {
        guard let repositoryURL else {
            throw AppError.repositoryNotSelected
        }

        let folders = [
            repositoryURL.appendingPathComponent("quesiti", isDirectory: true),
            repositoryURL.appendingPathComponent("test", isDirectory: true),
            repositoryURL.appendingPathComponent("eserciziario", isDirectory: true)
        ]

        for folder in folders {
            try fileManager.createDirectory(at: folder, withIntermediateDirectories: true, attributes: nil)
        }

        for materia in Materia.defaultInstallMaterie {
            try fileManager.createDirectory(at: quesitiFolder(for: materia), withIntermediateDirectories: true, attributes: nil)
        }
    }

    /// Cartelle `quesiti/Q - …` presenti su disco (più affidabile dell’elenco statico).
    func listMaterie() throws -> [Materia] {
        guard let repositoryURL else {
            throw AppError.repositoryNotSelected
        }
        let quesitiRoot = repositoryURL.appendingPathComponent("quesiti", isDirectory: true)
        guard fileManager.fileExists(atPath: quesitiRoot.path) else {
            return []
        }

        let prefix = "Q - "
        var names = Set<String>()
        for entry in try fileManager.contentsOfDirectory(at: quesitiRoot, includingPropertiesForKeys: [.isDirectoryKey]) {
            var isDir: ObjCBool = false
            guard fileManager.fileExists(atPath: entry.path, isDirectory: &isDir), isDir.boolValue else { continue }
            let folderName = entry.lastPathComponent
            guard folderName.hasPrefix(prefix) else { continue }
            let raw = String(folderName.dropFirst(prefix.count))
            if let m = Materia(rawValue: raw) {
                names.insert(m.rawValue)
            }
        }

        return names.sorted().map { Materia(validatedRawValue: $0) }
    }

    /// Crea `quesiti/Q - {nome}/` per una nuova materia.
    func addMateria(displayName: String) throws -> Materia {
        guard let materia = Materia(rawValue: displayName) else {
            throw AppError.invalidFileNameComponent(displayName.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        try ensureRepositoryStructure()
        let folder = try quesitiFolder(for: materia)
        if fileManager.fileExists(atPath: folder.path) {
            throw AppError.ioError("Esiste già una cartella per la materia «\(materia.rawValue)».")
        }
        try fileManager.createDirectory(at: folder, withIntermediateDirectories: true, attributes: nil)
        return materia
    }

    func quesitiFolder(for materia: Materia) throws -> URL {
        guard let repositoryURL else {
            throw AppError.repositoryNotSelected
        }
        return repositoryURL
            .appendingPathComponent("quesiti", isDirectory: true)
            .appendingPathComponent(materia.repositoryFolderName, isDirectory: true)
    }

    func testFolder() throws -> URL {
        guard let repositoryURL else {
            throw AppError.repositoryNotSelected
        }
        return repositoryURL.appendingPathComponent("test", isDirectory: true)
    }

    func eserciziarioFolder() throws -> URL {
        guard let repositoryURL else {
            throw AppError.repositoryNotSelected
        }
        return repositoryURL.appendingPathComponent("eserciziario", isDirectory: true)
    }

    func allQuestionFiles() throws -> [URL] {
        guard repositoryURL != nil else {
            throw AppError.repositoryNotSelected
        }

        return try listMaterie()
            .flatMap { try fileManager.contentsOfDirectory(at: quesitiFolder(for: $0), includingPropertiesForKeys: nil) }
            .filter { $0.pathExtension.lowercased() == "txt" }
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
    }

    private func persistBookmark(for url: URL) throws {
        let data = try url.bookmarkData(options: .minimalBookmark, includingResourceValuesForKeys: nil, relativeTo: nil)
        UserDefaults.standard.set(data, forKey: defaultsKey)
        UserDefaults.standard.set(url.path, forKey: pathKey)
    }

    private func resolveBookmark() -> URL? {
        if let data = UserDefaults.standard.data(forKey: defaultsKey) {
            var stale = false

            let optionSets: [URL.BookmarkResolutionOptions] = [
                [.withoutUI, .withSecurityScope],
                [.withoutUI],
            ]

            for opts in optionSets {
                if let url = try? URL(resolvingBookmarkData: data, options: opts, relativeTo: nil, bookmarkDataIsStale: &stale),
                   directoryExists(at: url) {
                    if stale {
                        try? persistBookmark(for: url)
                    }
                    return url
                }
            }
        }

        if let path = UserDefaults.standard.string(forKey: pathKey) {
            let url = URL(fileURLWithPath: path, isDirectory: true)
            if directoryExists(at: url) {
                if UserDefaults.standard.data(forKey: defaultsKey) == nil {
                    try? persistBookmark(for: url)
                }
                return url
            }
        }

        return nil
    }

    private func directoryExists(at url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        return fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) && isDirectory.boolValue
    }
}
