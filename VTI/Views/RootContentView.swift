import SwiftUI

struct RootContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var appViewModel: AppViewModel
    @StateObject private var quesitiViewModel: QuesitiViewModel
    @StateObject private var testViewModel: TestViewModel
    @StateObject private var eserciziarioViewModel: EserciziarioViewModel

    init() {
        let appViewModel = AppViewModel()
        _appViewModel = StateObject(wrappedValue: appViewModel)
        _quesitiViewModel = StateObject(wrappedValue: QuesitiViewModel(
            repositoryService: appViewModel.repositoryService,
            parserService: appViewModel.parserService,
            writerService: appViewModel.writerService,
            previewService: QuesitoPreviewService(
                latexService: appViewModel.latexService,
                pdfCompilerService: appViewModel.pdfCompilerService
            )
        ))
        _testViewModel = StateObject(wrappedValue: TestViewModel(
            generatorService: appViewModel.testGeneratorService,
            usageStore: appViewModel.testQuesitoUsageStore
        ))
        _eserciziarioViewModel = StateObject(wrappedValue: EserciziarioViewModel(generatorService: appViewModel.eserciziarioGeneratorService))
    }

    var body: some View {
        // `NavigationSplitView` su alcune versioni di macOS può mostrare sidebar/dettaglio
        // vuoti (solo titolo). `HSplitView` + `NavigationStack` replica il layout in modo stabile.
        HSplitView {
            VStack(alignment: .leading, spacing: 0) {
                Text("VTI")
                    .font(.title3.weight(.semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                Divider()
                List(SidebarSection.allCases, selection: $appViewModel.selectedSection) { section in
                    sidebarRow(for: section)
                        .tag(section)
                }
                .listStyle(.sidebar)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(minWidth: 220, idealWidth: 260, maxWidth: 360, maxHeight: .infinity, alignment: .topLeading)

            NavigationStack {
                VStack(alignment: .leading, spacing: 16) {
                    StatusBannerView(message: currentMessage)

                    switch appViewModel.selectedSection {
                    case .home:
                        HomeView(
                            repositoryURL: appViewModel.repositoryURL,
                            onChooseRepository: {
                                appViewModel.chooseRepository()
                                ViewUpdateDefer.async {
                                    quesitiViewModel.loadQuesiti()
                                }
                            },
                            onAddMateria: { name in
                                appViewModel.addMateria(named: name)
                                ViewUpdateDefer.async {
                                    quesitiViewModel.loadQuesiti()
                                }
                            }
                        )
                    case .quesitiRepository:
                        QuesitiRepositoryView(viewModel: quesitiViewModel)
                    case .quesitiPlus:
                        QuesitiPlusView(viewModel: quesitiViewModel)
                    case .test:
                        TestView(
                            viewModel: testViewModel,
                            quesitiViewModel: quesitiViewModel,
                            usageStore: appViewModel.testQuesitoUsageStore
                        )
                    case .eserciziario:
                        EserciziarioView(
                            viewModel: eserciziarioViewModel,
                            quesiti: quesitiViewModel.quesiti,
                            materieOrdered: quesitiViewModel.materieOrdered,
                            repositoryURL: appViewModel.repositoryURL,
                            onAddMateria: { name in
                                appViewModel.addMateria(named: name)
                                ViewUpdateDefer.async {
                                    quesitiViewModel.loadQuesiti()
                                }
                            }
                        )
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding()
                .navigationTitle(appViewModel.selectedSection.rawValue)
                .navigationSubtitle(appViewModel.selectedSection.detailSubtitle)
                .task {
                    ViewUpdateDefer.async {
                        quesitiViewModel.loadQuesiti()
                    }
                }
                .onChange(of: scenePhase) { phase in
                    if phase == .active {
                        ViewUpdateDefer.async {
                            quesitiViewModel.loadQuesiti()
                        }
                    }
                }
            }
            .frame(minWidth: 720, maxWidth: .infinity, minHeight: 400, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    private func sidebarRow(for section: SidebarSection) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: icon(for: section))
                .font(.title3)
                .foregroundStyle(.secondary)
                .frame(width: 26, alignment: .center)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(section.rawValue)
                    .font(.body.weight(.medium))
                Text(section.detailSubtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private func icon(for section: SidebarSection) -> String {
        switch section {
        case .home:
            return "house"
        case .quesitiRepository:
            return "folder.fill"
        case .quesitiPlus:
            return "plus.square.on.square"
        case .test:
            return "doc.text"
        case .eserciziario:
            return "books.vertical"
        }
    }

    private var currentMessage: UserMessage? {
        switch appViewModel.selectedSection {
        case .home:
            return appViewModel.message
        case .quesitiRepository, .quesitiPlus:
            return quesitiViewModel.message
        case .test:
            return testViewModel.message
        case .eserciziario:
            // Permette di mostrare esito «Aggiungi materia» (messaggio su AppViewModel) dalla stessa scheda.
            return eserciziarioViewModel.message ?? appViewModel.message
        }
    }
}
