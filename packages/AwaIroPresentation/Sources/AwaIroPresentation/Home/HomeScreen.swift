import SwiftUI

/// Pure state-driven content view — no async load, no ViewModel dependency.
/// Used directly by snapshot tests and composed inside HomeScreen.
struct HomeContentView: View {
  let state: HomeState

  var body: some View {
    ZStack {
      Color.black.ignoresSafeArea()
      content
    }
  }

  @ViewBuilder
  private var content: some View {
    switch state {
    case .loading:
      ProgressView()
        .tint(.white)
        .accessibilityLabel("読み込み中")

    case .unrecorded:
      Circle()
        .fill(.white.opacity(0.85))
        .frame(width: 200, height: 200)
        .accessibilityLabel("今日はまだ記録していません")

    case .recorded:
      Circle()
        .fill(.white.opacity(0.15))
        .frame(width: 200, height: 200)
        .accessibilityLabel("今日は記録しました")

    case .failed(let message):
      VStack(spacing: 12) {
        Text("読み込みに失敗しました")
          .foregroundStyle(.white)
        Text(message)
          .font(.caption)
          .foregroundStyle(.white.opacity(0.6))
      }
    }
  }
}

public struct HomeScreen: View {
  @State private var viewModel: HomeViewModel

  public init(viewModel: HomeViewModel) {
    _viewModel = State(initialValue: viewModel)
  }

  public var body: some View {
    HomeContentView(state: viewModel.state)
      .task {
        await viewModel.load(now: Date())
      }
  }
}

#if DEBUG
  #Preview("unrecorded") {
    HomeScreen(viewModel: PreviewHelpers.unrecordedVM())
  }

  #Preview("recorded") {
    HomeScreen(viewModel: PreviewHelpers.recordedVM())
  }
#endif
