import SwiftUI

struct RepositorySettingsView: View {
    @ObservedObject var appViewModel: AppViewModel
    @ObservedObject var quesitiViewModel: QuesitiViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Cartella di lavoro").font(.title3.bold())
            Text(appViewModel.repositoryURL?.path ?? "Nessuna cartella selezionata")
                .textSelection(.enabled)

            Button("Scegli cartella…") {
                appViewModel.chooseRepository()
                ViewUpdateDefer.async {
                    quesitiViewModel.loadQuesiti()
                }
            }
            .buttonStyle(.borderedProminent)

            VStack(alignment: .leading, spacing: 8) {
                Text("Struttura gestita automaticamente").font(.headline)
                Text("quesiti/")
                ForEach(quesitiViewModel.materieOrdered) { materia in
                    Text("quesiti/\(materia.repositoryFolderName)/")
                }
                Text("test/")
                Text("eserciziario/")
            }
            .padding()
            .background(.quaternary.opacity(0.25))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
