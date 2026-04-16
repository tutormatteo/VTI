import Combine
import Foundation

/// Traccia i nomi file dei quesiti già inclusi in un test per cui è stato generato il PDF,
/// per poterli escludere dalle estrazioni casuali successive.
@MainActor
final class TestQuesitoUsageStore: ObservableObject {
    private static let fileName = "test_used_quesiti_filenames.json"

    @Published private(set) var usedCount: Int = 0

    private var usedFileNames: Set<String> = []
    private let fileURL: URL

    init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("VTI", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        fileURL = base.appendingPathComponent(Self.fileName)
        load()
        usedCount = usedFileNames.count
    }

    func contains(_ fileName: String) -> Bool {
        usedFileNames.contains(fileName)
    }

    func markUsed(fileNames: [String]) {
        guard !fileNames.isEmpty else { return }
        for name in fileNames {
            usedFileNames.insert(name)
        }
        usedCount = usedFileNames.count
        save()
    }

    func removeAll() {
        usedFileNames.removeAll()
        usedCount = 0
        save()
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([String].self, from: data) else {
            return
        }
        usedFileNames = Set(decoded)
    }

    private func save() {
        let list = usedFileNames.sorted()
        guard let data = try? JSONEncoder().encode(list) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
