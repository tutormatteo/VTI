import SwiftUI
import AppKit

struct EserciziarioView: View {
    @ObservedObject var viewModel: EserciziarioViewModel
    let quesiti: [Quesito]
    let materieOrdered: [Materia]
    let repositoryURL: URL?
    let onAddMateria: (String) -> Void

    @State private var nuovaMateriaNome = ""

    var body: some View {
        ZStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Scegli se includere tutte le materie o solo una, poi genera TEX e, se pdflatex è disponibile, anche il PDF.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    materiaAggiuntaSection

                    Picker("Ambito", selection: $viewModel.scope) {
                        ForEach(EserciziarioScope.allCases) { scope in
                            Text(scope.rawValue).tag(scope)
                        }
                    }
                    .pickerStyle(.segmented)

                    if viewModel.scope == .materiaSingola {
                        if materieOrdered.isEmpty {
                            Text("Nessuna cartella materia: imposta la repository o aggiungi una materia qui sopra.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            Picker("Materia", selection: $viewModel.materia) {
                                ForEach(materieOrdered) { materia in
                                    Text(materia.rawValue).tag(materia)
                                }
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Label("\(quesiti.count) quesiti nel repository", systemImage: "doc.text.magnifyingglass")
                            .font(.body.weight(.medium))
                        if quesiti.isEmpty {
                            Text("Carica la repository dalla Home o ricarica i quesiti.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Button {
                        viewModel.generate(from: quesiti)
                    } label: {
                        Label("Genera eserciziario", systemImage: "doc.badge.arrow.up")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(quesiti.isEmpty || viewModel.isGenerating)

                    if let document = viewModel.generatedDocument {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Ultimo output")
                                .font(.headline)
                            Group {
                                pathRow(label: "TEX", path: document.texURL.path)
                                pathRow(
                                    label: "PDF",
                                    path: document.pdfURL?.path,
                                    placeholder: "non generato"
                                )
                            }
                            .font(.callout)
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
                            Text("Log compilazione")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Text(document.log)
                                .font(.caption.monospaced())
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(10)
                                .background(Color(nsColor: .textBackgroundColor))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.quaternary.opacity(0.22))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(Color(nsColor: .separatorColor).opacity(0.4), lineWidth: 1)
                        )
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Quesiti per materia")
                            .font(.headline)
                        VStack(spacing: 0) {
                            ForEach(Array(materieOrdered.enumerated()), id: \.element.id) { index, materia in
                                let count = quesiti.filter { $0.materia == materia }.count
                                HStack {
                                    Text(materia.rawValue)
                                        .font(.body)
                                    Spacer()
                                    Text("\(count)")
                                        .font(.body.monospacedDigit().weight(.medium))
                                        .foregroundStyle(count > 0 ? .primary : .tertiary)
                                    Text("quesiti")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.vertical, 8)
                                if index < materieOrdered.count - 1 {
                                    Divider()
                                }
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
                .frame(maxWidth: 720, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if viewModel.isGenerating {
                ProcessingOverlayView(
                    title: "Creazione eserciziario in corso",
                    subtitle: viewModel.processingStatus
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            viewModel.syncMateriaSelection(available: materieOrdered)
        }
        .onChange(of: materieOrdered) { new in
            viewModel.syncMateriaSelection(available: new)
        }
    }

    private var materiaAggiuntaSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Nuova materia")
                .font(.subheadline.weight(.semibold))
            Text("Crea la cartella quesiti/Q - Nome/ nel repository corrente.")
                .font(.caption2)
                .foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                TextField("Nome (es. Fisica)", text: $nuovaMateriaNome)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 320)
                Button("Aggiungi") {
                    onAddMateria(nuovaMateriaNome)
                    nuovaMateriaNome = ""
                }
                .disabled(
                    nuovaMateriaNome.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        || repositoryURL == nil
                )
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func pathRow(label: String, path: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 40, alignment: .leading)
            Text(path)
                .textSelection(.enabled)
                .lineLimit(3)
        }
    }

    private func pathRow(label: String, path: String?, placeholder: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 40, alignment: .leading)
            if let path {
                Text(path)
                    .textSelection(.enabled)
                    .lineLimit(3)
            } else {
                Text(placeholder)
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

