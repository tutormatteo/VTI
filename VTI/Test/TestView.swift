import AppKit
import SwiftUI

private enum SplitColumnLayout {
    static let gutter: CGFloat = 24
}

struct TestView: View {
    @ObservedObject var viewModel: TestViewModel
    @ObservedObject var quesitiViewModel: QuesitiViewModel
    @ObservedObject var usageStore: TestQuesitoUsageStore

    var body: some View {
        let previewQuesiti = viewModel.selectedQuesiti(from: quesitiViewModel.quesiti)

        ZStack {
            VStack(spacing: 0) {
                headerBar(previewCount: previewQuesiti.count)

                // HStack al posto di HSplitView: NSSplitView può andare in loop di constraint
                // ridimensionando la finestra (es. da schermo intero a finestra libera).
                HStack(alignment: .top, spacing: 0) {
                    configurationColumn
                        .frame(minWidth: 360, idealWidth: 520, maxWidth: .infinity)
                        .padding(.trailing, SplitColumnLayout.gutter)

                    Divider()

                    selectionPreviewColumn(previewQuesiti)
                        .frame(minWidth: 260, idealWidth: 380, maxWidth: .infinity)
                        .padding(.leading, SplitColumnLayout.gutter)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                if let document = viewModel.generatedDocument {
                    outputSection(document)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.top, 4)

            if viewModel.isGenerating {
                ProcessingOverlayView(
                    title: "Creazione test in corso",
                    subtitle: viewModel.processingStatus
                )
                .transition(.opacity)
                .zIndex(1)
            }
        }
        .task {
            ViewUpdateDefer.async {
                if quesitiViewModel.quesiti.isEmpty {
                    quesitiViewModel.loadQuesiti()
                }
            }
        }
        .onAppear {
            ViewUpdateDefer.async {
                if viewModel.selectionMode == .random {
                    viewModel.estraiRandom(from: quesitiViewModel.quesiti)
                }
            }
        }
        .onChange(of: viewModel.selectionMode) { mode in
            ViewUpdateDefer.async {
                if mode == .random {
                    viewModel.estraiRandom(from: quesitiViewModel.quesiti)
                }
            }
        }
        .onChange(of: quesitiViewModel.quesiti.count) { _ in
            ViewUpdateDefer.async {
                if viewModel.selectionMode == .random {
                    viewModel.clampRandomRequestsToEligible(allQuesiti: quesitiViewModel.quesiti)
                    viewModel.estraiRandom(from: quesitiViewModel.quesiti)
                }
            }
        }
        .onChange(of: viewModel.excludeUsedFromRandomExtractions) { _ in
            ViewUpdateDefer.async {
                viewModel.clampRandomRequestsToEligible(allQuesiti: quesitiViewModel.quesiti)
                viewModel.estraiRandom(from: quesitiViewModel.quesiti)
            }
        }
        .onAppear {
            ViewUpdateDefer.async {
                if viewModel.expandedMaterie.isEmpty {
                    viewModel.expandedMaterie = Set(quesitiViewModel.materieOrdered)
                } else {
                    viewModel.expandedMaterie.formUnion(Set(quesitiViewModel.materieOrdered))
                }
            }
        }
        .onChange(of: quesitiViewModel.materieOrdered) { newMaterie in
            ViewUpdateDefer.async {
                viewModel.expandedMaterie.formUnion(Set(newMaterie))
            }
        }
    }

    // MARK: - Header

    private func headerBar(previewCount: Int) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Generazione test")
                .font(.title2.bold())

            HStack(alignment: .center, spacing: 16) {
                TextField("Titolo test", text: $viewModel.titoloTest)
                    .textFieldStyle(.roundedBorder)
                    .frame(minWidth: 220, maxWidth: 400)

                DatePicker("Data", selection: $viewModel.dataTest, displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .labelsHidden()
                    .help("Data sul test")

                Picker("Modalità", selection: $viewModel.selectionMode) {
                    ForEach(TestSelectionMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(minWidth: 200, maxWidth: 280)

                Spacer(minLength: 8)

                Label {
                    Text("\(previewCount)")
                        .font(.headline.monospacedDigit())
                } icon: {
                    Image(systemName: "doc.on.doc")
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))

                Button {
                    viewModel.clearForNewGeneration()
                } label: {
                    Label("Azzera", systemImage: "arrow.counterclockwise.circle")
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .help("Rimuove selezione, ultimo output e messaggi; titolo e data tornano ai default.")
                .disabled(viewModel.isGenerating)

                Button {
                    viewModel.generate(from: quesitiViewModel.quesiti)
                } label: {
                    Label("Genera test", systemImage: "doc.badge.arrow.up")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(previewCount == 0 || viewModel.isGenerating)
            }
        }
        .padding(.horizontal, 4)
        .padding(.bottom, 12)
    }

    // MARK: - Colonna configurazione

    @ViewBuilder
    private var configurationColumn: some View {
        VStack(alignment: .leading, spacing: 0) {
            if viewModel.selectionMode == .random {
                randomSelectionPanel
            } else {
                manualSelectionPanel
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.45))
    }

    private var randomSelectionPanel: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Estrazione casuale per materia e argomento")
                        .font(.headline)
                    Spacer()
                    Button {
                        viewModel.estraiRandom(from: quesitiViewModel.quesiti)
                    } label: {
                        Label("Estrai", systemImage: "shuffle")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .help("Sorteggia di nuovo i quesiti con le stesse quantità.")
                }
                .padding(.bottom, 8)

                GroupBox {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Opzione facoltativa")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)

                        Toggle(isOn: $viewModel.excludeUsedFromRandomExtractions) {
                            Text("Non ripetere quesiti già usati in test con PDF")
                        }
                        .help("Se attivo, nelle estrazioni casuali non vengono sorteggiati i file già entrati in un test per cui è stato generato il PDF.")

                        Text("Disattivata di default: tutti i quesiti restano estraibili. Attivala solo se vuoi evitare ripetizioni; lo storico file viene comunque registrato dopo ogni PDF.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        if usageStore.usedCount > 0 {
                            HStack(spacing: 12) {
                                Text("Storico utilizzi: \(usageStore.usedCount) file")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Button("Svuota storico") {
                                    ViewUpdateDefer.async {
                                        viewModel.clearTestUsageHistory()
                                        viewModel.clampRandomRequestsToEligible(allQuesiti: quesitiViewModel.quesiti)
                                        viewModel.estraiRandom(from: quesitiViewModel.quesiti)
                                    }
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                                .help("Rimuove i nomi file dallo storico (non elimina i PDF già creati). Utile soprattutto con l’opzione di esclusione attiva.")
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 2)
                }
                .padding(.bottom, 10)

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 6) {
                        let groups = viewModel.availableGroups(from: quesitiViewModel.quesiti)
                        let allQuesiti = quesitiViewModel.quesiti
                        ForEach(quesitiViewModel.materieOrdered) { materia in
                            let argomenti = groups[materia] ?? [:]
                            if !argomenti.isEmpty {
                                DisclosureGroup(
                                    isExpanded: Binding(
                                        get: { viewModel.expandedMaterie.contains(materia) },
                                        set: { isExpanded in
                                            if isExpanded {
                                                viewModel.expandedMaterie.insert(materia)
                                            } else {
                                                viewModel.expandedMaterie.remove(materia)
                                            }
                                        }
                                    )
                                ) {
                                    ForEach(argomenti.keys.sorted(), id: \.self) { argomento in
                                        let key = ArgomentoGroupKey(materia: materia, argomento: argomento)
                                        let totalCount = argomenti[argomento]?.count ?? 0
                                        let eligible = viewModel.eligibleCount(for: key, allQuesiti: allQuesiti)
                                        let current = viewModel.requestedCount(for: key)
                                        HStack(alignment: .center) {
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(argomento)
                                                    .font(.body)
                                                Group {
                                                    if viewModel.excludeUsedFromRandomExtractions, eligible < totalCount {
                                                        Text("\(eligible) disponibili per estrazione (\(totalCount - eligible) già usati in test con PDF)")
                                                    } else {
                                                        Text("\(totalCount) disponibili")
                                                    }
                                                }
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                            }
                                            Spacer(minLength: 12)
                                            randomQuantityStepper(
                                                key: key,
                                                current: current,
                                                eligibleMax: eligible,
                                                allQuesiti: allQuesiti
                                            )
                                        }
                                        .padding(.vertical, 4)
                                    }
                                } label: {
                                    HStack {
                                        Text(materia.rawValue)
                                            .font(.body.weight(.semibold))
                                        Spacer()
                                        Text("\(argomenti.count) argomenti")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
                .frame(maxWidth: .infinity)

                Divider()
                    .padding(.vertical, 8)

                Text("Riepilogo richieste")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)

                let summary = viewModel.summaryByMateria()
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(quesitiViewModel.materieOrdered) { materia in
                        let n = summary[materia, default: 0]
                        HStack {
                            Text(materia.rawValue)
                            Spacer()
                            Text("\(n)")
                                .monospacedDigit()
                                .foregroundStyle(n > 0 ? .primary : .tertiary)
                        }
                        .font(.callout)
                    }
                }
                .padding(.top, 4)
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .padding(4)
        }
        .frame(maxWidth: .infinity)
    }

    private func randomQuantityStepper(
        key: ArgomentoGroupKey,
        current: Int,
        eligibleMax: Int,
        allQuesiti: [Quesito]
    ) -> some View {
        HStack(spacing: 8) {
            Text("Estrarre")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(spacing: 0) {
                Button {
                    viewModel.setRandomRequest(
                        for: key,
                        value: current - 1,
                        allQuesiti: allQuesiti
                    )
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .symbolRenderingMode(.hierarchical)
                }
                .buttonStyle(.plain)
                .disabled(current <= 0)
                .help("Diminuisci")

                Text("\(current)")
                    .font(.body.weight(.medium))
                    .monospacedDigit()
                    .frame(minWidth: 28)
                    .multilineTextAlignment(.center)

                Button {
                    viewModel.setRandomRequest(
                        for: key,
                        value: current + 1,
                        allQuesiti: allQuesiti
                    )
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .symbolRenderingMode(.hierarchical)
                }
                .buttonStyle(.plain)
                .disabled(current >= eligibleMax)
                .help("Aumenta")
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 8))
        }
    }

    private var manualSelectionPanel: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                Text("Scegli i file da includere nel test")
                    .font(.headline)

                Text("Clicca il cerchio per includere o escludere. L’elenco a destra mostra l’anteprima ordinata.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                List(quesitiViewModel.quesiti) { quesito in
                    HStack(alignment: .top, spacing: 10) {
                        Button {
                            viewModel.toggleSelection(for: quesito)
                        } label: {
                            Image(systemName: viewModel.manualSelection.contains(quesito.id) ? "checkmark.circle.fill" : "circle")
                                .font(.title3)
                                .symbolRenderingMode(.hierarchical)
                                .foregroundStyle(viewModel.manualSelection.contains(quesito.id) ? Color.accentColor : .secondary)
                        }
                        .buttonStyle(.plain)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(quesito.fileName)
                                .font(.body.weight(.medium))
                                .lineLimit(2)
                            Text("\(quesito.materia.rawValue) · \(quesito.argomento)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 2)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        viewModel.toggleSelection(for: quesito)
                    }
                }
                .listStyle(.inset)
                .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Anteprima selezione

    private func selectionPreviewColumn(_ previewQuesiti: [Quesito]) -> some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("Nel test")
                        .font(.headline)
                    Spacer()
                    Text("\(previewQuesiti.count) quesiti")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.bottom, 6)

                if previewQuesiti.isEmpty {
                    emptySelectionPlaceholder
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            ForEach(Array(previewQuesiti.enumerated()), id: \.element.id) { index, quesito in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(quesito.fileName)
                                        .font(.body.weight(.medium))
                                        .lineLimit(2)
                                    Text("\(quesito.materia.rawValue) · \(quesito.argomento)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 8)
                                .padding(.horizontal, 4)

                                if index < previewQuesiti.count - 1 {
                                    Divider()
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .padding(4)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Output

    private func outputSection(_ document: GeneratedDocument) -> some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Ultimo file generato")
                        .font(.headline)
                    Spacer()
                    HStack(spacing: 10) {
                        Button("Apri TEX") {
                            NSWorkspace.shared.open(document.texURL)
                        }
                        .buttonStyle(.bordered)

                        Button("Apri PDF") {
                            guard let pdfURL = document.pdfURL else { return }
                            NSWorkspace.shared.open(pdfURL)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(document.pdfURL == nil)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    pathLine(label: "TEX", url: document.texURL)
                    pathLine(label: "PDF", url: document.pdfURL, missingText: "non generato")
                }
                .font(.caption)

                Text("Log compilazione")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                ScrollView {
                    Text(document.log)
                        .font(.caption.monospaced())
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(minHeight: 80, maxHeight: 160)
                .padding(8)
                .background(Color(nsColor: .textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(4)
        }
        .padding(.top, 8)
    }

    private var emptySelectionPlaceholder: some View {
        VStack {
            Spacer(minLength: 0)
            VStack(spacing: 12) {
                Image(systemName: "tray")
                    .font(.system(size: 36))
                    .foregroundStyle(.tertiary)
                Text("Nessuna selezione")
                    .font(.headline)
                Text(
                    viewModel.selectionMode == .random
                        ? "Imposta quanti quesiti estrarre per argomento."
                        : "Seleziona i file dalla colonna di sinistra."
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 280)
            }
            .frame(maxWidth: .infinity)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
    }

    private func pathLine(label: String, url: URL?, missingText: String? = nil) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(label)
                .foregroundStyle(.secondary)
                .frame(width: 36, alignment: .leading)
            if let url {
                Text(url.path)
                    .textSelection(.enabled)
                    .lineLimit(2)
            } else if let missingText {
                Text(missingText)
                    .foregroundStyle(.tertiary)
            }
        }
    }
}
