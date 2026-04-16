import SwiftUI
import AppKit

private enum SplitColumnLayout {
    /// Spazio tra `Divider` e contenuto delle colonne (padding orizzontale interno).
    static let gutter: CGFloat = 24
}

// MARK: - Quesiti+ (crea / importa)

struct QuesitiPlusView: View {
    @ObservedObject var viewModel: QuesitiViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Crea o importa quesito")
                    .font(.title2.bold())
                Spacer()
                Button {
                    viewModel.clearQuesitiPlusForm()
                } label: {
                    Label("Azzera", systemImage: "arrow.counterclockwise.circle")
                }
                .buttonStyle(.bordered)
                .help("Pulisce bozza, import e anteprima; torna alla modalità Crea.")
            }

            Picker("Modalita", selection: $viewModel.inputMode) {
                ForEach(QuesitiInputMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .onChange(of: viewModel.inputMode) { mode in
                if mode != .create {
                    ViewUpdateDefer.async {
                        viewModel.clearPreview()
                    }
                }
            }

            if viewModel.inputMode == .create {
                HStack(alignment: .top, spacing: 0) {
                    ScrollView {
                        QuesitoCreateFormOnly(viewModel: viewModel)
                    }
                    .frame(minWidth: 300, idealWidth: 380, maxWidth: .infinity)
                    .padding(.trailing, SplitColumnLayout.gutter)

                    Divider()

                    VStack(alignment: .leading, spacing: 10) {
                        QuesitoPDFPreviewPanel(mode: .draft, viewModel: viewModel)

                        Button("Salva quesito") {
                            viewModel.saveDraft()
                        }
                        .buttonStyle(.borderedProminent)
                        .keyboardShortcut(.defaultAction)
                    }
                    .frame(minWidth: 280, idealWidth: 360, maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, SplitColumnLayout.gutter)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .onAppear {
                    ViewUpdateDefer.async {
                        viewModel.scheduleDraftPreviewDebounced()
                    }
                }
                .onChange(of: viewModel.draft) { _ in
                    ViewUpdateDefer.async {
                        viewModel.scheduleDraftPreviewDebounced()
                    }
                }
            } else {
                HStack(alignment: .top, spacing: 0) {
                    ScrollView {
                        QuesitoImportFormOnly(viewModel: viewModel)
                    }
                    .frame(minWidth: 300, idealWidth: 380, maxWidth: .infinity)
                    .padding(.trailing, SplitColumnLayout.gutter)

                    Divider()

                    VStack(alignment: .leading, spacing: 12) {
                        Spacer(minLength: 0)
                        Image(systemName: "arrow.down.doc")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        (Text("Dopo l'import apri la scheda ") + Text("Repository quesiti").bold() + Text(" per vedere il file nell'elenco."))
                            .font(.callout)
                            .foregroundStyle(.secondary)
                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .padding(.leading, SplitColumnLayout.gutter)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

// MARK: - Repository quesiti (solo elenco e anteprima)

struct QuesitiRepositoryView: View {
    @ObservedObject var viewModel: QuesitiViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Elenco per materia e argomento")
                    .font(.title3.bold())
                Spacer()
                Button("Ricarica") { viewModel.loadQuesiti() }
            }

            Text("Materia → Argomento → file .txt")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(alignment: .top, spacing: 0) {
                List {
                    ForEach(viewModel.materieOrdered) { materia in
                        let argomenti = viewModel.groupedQuesiti[materia] ?? [:]
                        DisclosureGroup(
                            isExpanded: Binding(
                                get: { viewModel.expandedMaterie.contains(materia) },
                                set: { isExpanded in
                                    if isExpanded { viewModel.expandedMaterie.insert(materia) }
                                    else { viewModel.expandedMaterie.remove(materia) }
                                }
                            )
                        ) {
                            ForEach(argomenti.keys.sorted(), id: \.self) { argomento in
                                let key = viewModel.argomentoKey(materia: materia, argomento: argomento)
                                let files = argomenti[argomento] ?? []
                                DisclosureGroup(
                                    isExpanded: Binding(
                                        get: { viewModel.expandedArgomenti.contains(key) },
                                        set: { isExpanded in
                                            if isExpanded { viewModel.expandedArgomenti.insert(key) }
                                            else { viewModel.expandedArgomenti.remove(key) }
                                        }
                                    )
                                ) {
                                    ForEach(files) { quesito in
                                        Button {
                                            viewModel.selectedQuesito = quesito
                                        } label: {
                                            HStack {
                                                Image(systemName: viewModel.selectedQuesito?.id == quesito.id ? "doc.text.fill" : "doc.text")
                                                Text(quesito.fileName)
                                                    .lineLimit(1)
                                                Spacer()
                                            }
                                        }
                                        .buttonStyle(.plain)
                                        .padding(.vertical, 1)
                                    }
                                } label: {
                                    HStack {
                                        Text(argomento)
                                        Spacer()
                                        Text("\(files.count)")
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        } label: {
                            HStack {
                                Text(materia.rawValue).bold()
                                Spacer()
                                Text("\(viewModel.totalCount(for: materia))")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .listStyle(.inset)
                .frame(minWidth: 280, idealWidth: 380, maxWidth: 480)
                .padding(.trailing, SplitColumnLayout.gutter)

                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Text("Anteprima file selezionato")
                        .font(.headline)

                    if let selected = viewModel.selectedQuesito {
                        HStack(spacing: 10) {
                            Button("Apri file") {
                                NSWorkspace.shared.open(selected.urlFile)
                            }
                            .buttonStyle(.borderedProminent)

                            Button("Mostra nel Finder") {
                                NSWorkspace.shared.activateFileViewerSelecting([selected.urlFile])
                            }
                            .buttonStyle(.bordered)

                            Text(selected.urlFile.path)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                                .textSelection(.enabled)
                        }
                    }

                    QuesitoPDFPreviewPanel(mode: .repository, viewModel: viewModel)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, SplitColumnLayout.gutter)
                .onAppear {
                    ViewUpdateDefer.async {
                        viewModel.refreshPreviewForSelectedQuesito()
                    }
                }
                .onChange(of: viewModel.selectedQuesito?.id) { _ in
                    ViewUpdateDefer.async {
                        viewModel.refreshPreviewForSelectedQuesito()
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

// MARK: - Solo form creazione

private struct QuesitoCreateFormOnly: View {
    @ObservedObject var viewModel: QuesitiViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Dati quesito")
                .font(.title3.bold())

            if viewModel.materieOrdered.isEmpty {
                Text("Aggiungi una materia dalla Home: viene creata la cartella quesiti/Q - Nome/.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Picker("Materia", selection: $viewModel.draft.materia) {
                    ForEach(viewModel.materieOrdered) { materia in
                        Text(materia.rawValue).tag(materia)
                    }
                }
            }
            TextField("Argomento", text: $viewModel.draft.argomento)
            TextField("Titolo", text: $viewModel.draft.titolo)
            TextField("Testo domanda in LaTeX", text: $viewModel.draft.testoDomanda, axis: .vertical)
                .lineLimit(4...10)

            VStack(alignment: .leading, spacing: 8) {
                Text("Opzioni (sempre 5)")
                    .font(.headline)
                ForEach(0..<5, id: \.self) { index in
                    HStack(alignment: .top) {
                        TextField("Opzione \(index + 1)", text: $viewModel.draft.opzioni[index], axis: .vertical)
                        Button(viewModel.draft.rispostaCorretta == index + 1 ? "Corretta" : "Segna") {
                            viewModel.draft.rispostaCorretta = index + 1
                        }
                        .controlSize(.small)
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.2))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Solo form import

private struct QuesitoImportFormOnly: View {
    @ObservedObject var viewModel: QuesitiViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Importa file TXT")
                .font(.title3.bold())

            HStack {
                Text(viewModel.importFileURL?.lastPathComponent ?? "Nessun file selezionato")
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer()
                Button("Scegli file TXT") {
                    viewModel.pickImportTXTFile()
                }
            }
            if viewModel.materieOrdered.isEmpty {
                Text("Aggiungi una materia dalla Home prima di scegliere la materia di destinazione.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Picker("Materia", selection: $viewModel.importMateria) {
                    ForEach(viewModel.materieOrdered) { materia in
                        Text(materia.rawValue).tag(materia)
                    }
                }
            }
            TextField("Argomento", text: $viewModel.importArgomento)
            TextField("Titolo", text: $viewModel.importTitolo)

            Button("Importa file") {
                viewModel.importTXT()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.2))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
