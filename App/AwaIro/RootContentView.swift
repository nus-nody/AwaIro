import AwaIroPresentation
import SwiftUI

struct RootContentView: View {
  let container: AppContainer
  @State private var path: [AppRoute] = []

  var body: some View {
    NavigationStack(path: $path) {
      HomeScreen(
        viewModel: container.makeHomeViewModel(),
        camera: container.camera,
        onCaptured: { url, takenAt in
          path.append(.memo(fileURL: url, takenAt: takenAt))
        }
      )
      .navigationBarHidden(true)
      .navigationDestination(for: AppRoute.self) { route in
        switch route {
        case .memo(let fileURL, let takenAt):
          MemoScreen(
            viewModel: container.makeMemoViewModel(fileURL: fileURL, takenAt: takenAt),
            onFinished: {
              path.removeAll()
            }
          )
          .navigationBarHidden(true)
        }
      }
    }
    .preferredColorScheme(.dark)
  }
}
