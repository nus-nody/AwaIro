import SwiftUI

@main
struct AwaIroApp: App {
    @State private var container: AppContainer?
    @State private var initError: String?

    var body: some Scene {
        WindowGroup {
            if let container {
                RootContentView(container: container)
            } else if let initError {
                Text("起動に失敗しました\n\(initError)")
                    .multilineTextAlignment(.center)
                    .padding()
            } else {
                ProgressView()
                    .task {
                        do {
                            container = try AppContainer()
                        } catch {
                            initError = String(describing: error)
                        }
                    }
            }
        }
    }
}
