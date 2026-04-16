import SwiftUI

@main
struct VTI_macOSApp: App {
    var body: some Scene {
        WindowGroup {
            RootContentView()
                .frame(minWidth: 1180, minHeight: 760)
        }
        .windowStyle(.automatic)
    }
}
