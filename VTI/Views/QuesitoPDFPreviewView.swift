import AppKit
import PDFKit
import SwiftUI

struct QuesitoPDFKitView: NSViewRepresentable {
    let url: URL?

    final class Coordinator {
        var lastURL: URL?
        var lastContentModification: Date?
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePage
        view.displayDirection = .vertical
        view.backgroundColor = .white
        return view
    }

    func updateNSView(_ pdfView: PDFView, context: Context) {
        if let url {
            let mod = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
            let sameSnapshot =
                context.coordinator.lastURL == url
                && context.coordinator.lastContentModification == mod
            guard !sameSnapshot else { return }
            context.coordinator.lastURL = url
            context.coordinator.lastContentModification = mod
            pdfView.document = PDFDocument(url: url)
            DispatchQueue.main.async {
                pdfView.layoutDocumentView()
            }
        } else {
            guard context.coordinator.lastURL != nil else { return }
            context.coordinator.lastURL = nil
            context.coordinator.lastContentModification = nil
            pdfView.document = nil
        }
    }
}

enum QuesitoPreviewPanelMode {
    case draft
    case repository
}

struct QuesitoPDFPreviewPanel: View {
    let mode: QuesitoPreviewPanelMode
    @ObservedObject var viewModel: QuesitiViewModel

    private var suggestedPNGName: String {
        switch mode {
        case .draft:
            return "Anteprima_quesito.png"
        case .repository:
            guard let name = viewModel.selectedQuesito?.fileName else {
                return "Quesito.png"
            }
            let base = (name as NSString).deletingPathExtension
            return "\(base).png"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("Anteprima PDF")
                    .font(.headline)
                Spacer()
                Button("Aggiorna") {
                    switch mode {
                    case .draft:
                        viewModel.runDraftPreviewImmediately()
                    case .repository:
                        viewModel.refreshPreviewForSelectedQuesito()
                    }
                }
                .keyboardShortcut("r", modifiers: [.command])

                Button("Esporta PNG…") {
                    viewModel.exportPreviewPNG(suggestedFileName: suggestedPNGName)
                }
            }

            ZStack {
                if viewModel.previewLoading {
                    ProgressView("Compilazione con pdflatex…")
                        .frame(maxWidth: .infinity, minHeight: 220)
                } else if let err = viewModel.previewError, viewModel.previewPDFURL == nil {
                    Text(err)
                        .font(.callout)
                        .foregroundStyle(.red)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, minHeight: 220, alignment: .topLeading)
                        .padding(8)
                } else if let url = viewModel.previewPDFURL {
                    QuesitoPDFKitView(url: url)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay {
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(.quaternary, lineWidth: 1)
                        }
                } else {
                    Text(placeholderText)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding()
                        .frame(maxWidth: .infinity, minHeight: 220)
                }
            }
            .frame(minHeight: 260)
            .background(Color(nsColor: .textBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            Text("Richiede pdflatex (MacTeX). Stessi pacchetti del test; pagina ridotta orizzontale (~¼ A4), senza titolo né numerazione.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    private var placeholderText: String {
        switch mode {
        case .draft:
            return "Compila argomento, titolo, testo domanda e tutte le opzioni per vedere l'anteprima."
        case .repository:
            return "Seleziona un file dall'elenco per l'anteprima."
        }
    }
}
