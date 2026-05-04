import SwiftUI
import AwaIroPresentation

struct RootContentView: View {
    let container: AppContainer

    var body: some View {
        NavigationStack {
            HomeScreen(viewModel: container.makeHomeViewModel())
                .navigationBarHidden(true)
        }
        .preferredColorScheme(.dark)
    }
}
