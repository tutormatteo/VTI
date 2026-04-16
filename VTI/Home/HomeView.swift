import AppKit
import SwiftUI

struct HomeView: View {
    let repositoryURL: URL?
    let onChooseRepository: () -> Void
    let onAddMateria: (String) -> Void

    @State private var nuovaMateriaNome = ""

    private let columnSpacing: CGFloat = 12

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Panoramica")
                    .font(.title3.weight(.semibold))
                Text("Banca dati quesiti, file compatibili con il formato esistente, test ed eserciziari in LaTeX e PDF.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(alignment: .top, spacing: columnSpacing) {
                compactStep(
                    number: 1,
                    title: "Repository",
                    detail: "Cartella con quesiti/, test/, eserciziario/.",
                    systemImage: "folder.badge.gearshape"
                )
                compactStep(
                    number: 2,
                    title: "Quesiti",
                    detail: "Crea o importa in Quesiti+; elenco in Repository.",
                    systemImage: "doc.badge.plus"
                )
                compactStep(
                    number: 3,
                    title: "Test ed eserciziario",
                    detail: "Random o manuale; PDF con pdflatex se installato.",
                    systemImage: "doc.text.image"
                )
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color(nsColor: .separatorColor).opacity(0.55), lineWidth: 1)
            )

            VStack(alignment: .leading, spacing: 8) {
                Text("Repository locale")
                    .font(.subheadline.weight(.semibold))
                Text(repositoryURL?.path ?? "Nessuna cartella selezionata.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .textSelection(.enabled)

                Button {
                    onChooseRepository()
                } label: {
                    Label("Scegli cartella repository", systemImage: "folder")
                }
                .buttonStyle(.borderedProminent)

                Text("Struttura: quesiti/, test/, eserciziario/")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Nuova materia")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text("Crea la cartella quesiti/Q - Nome/ (stesso schema delle materie predefinite).")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        TextField("Nome materia", text: $nuovaMateriaNome)
                            .textFieldStyle(.roundedBorder)
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
                .padding(.top, 6)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Text("Funzionalità")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: columnSpacing),
                    GridItem(.flexible(), spacing: columnSpacing)
                ],
                alignment: .leading,
                spacing: columnSpacing
            ) {
                featureTile(
                    title: "Creazione quesiti",
                    detail: "Quesiti+: nuovo file .txt; Repository: elenco e anteprima.",
                    icon: "square.and.pencil"
                )
                featureTile(
                    title: "Generazione test",
                    detail: "Random o manuale, export .tex e compilazione .pdf.",
                    icon: "shuffle"
                )
                featureTile(
                    title: "Eserciziario",
                    detail: "Volume intero o per materia in repository/eserciziario.",
                    icon: "books.vertical.fill"
                )
                featureTile(
                    title: "PDF e MacTeX",
                    detail: "Serve pdflatex nel sistema (es. MacTeX).",
                    icon: "curlybraces.square"
                )
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: 720, alignment: .leading)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func compactStep(number: Int, title: String, detail: String, systemImage: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.15))
                    .frame(width: 28, height: 28)
                Text("\(number)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.accentColor)
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Image(systemName: systemImage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(title)
                        .font(.caption.weight(.semibold))
                }
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func featureTile(title: String, detail: String, icon: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(Color.accentColor)
                .frame(width: 22, alignment: .center)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.weight(.semibold))
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }
}
