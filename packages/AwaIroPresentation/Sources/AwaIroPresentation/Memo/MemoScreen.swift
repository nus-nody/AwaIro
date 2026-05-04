import SwiftUI

public struct MemoScreen: View {
  @State private var viewModel: MemoViewModel
  private let onFinished: () -> Void

  public init(viewModel: MemoViewModel, onFinished: @escaping () -> Void) {
    _viewModel = State(initialValue: viewModel)
    self.onFinished = onFinished
  }

  public var body: some View {
    ZStack {
      Color.black.ignoresSafeArea()
      content
    }
    .onChange(of: stateID) { _, _ in
      if case .saved = viewModel.state {
        onFinished()
      }
    }
  }

  private var stateID: String {
    switch viewModel.state {
    case .editing: return "editing"
    case .saving: return "saving"
    case .saved: return "saved"
    case .failed: return "failed"
    }
  }

  @ViewBuilder
  private var content: some View {
    VStack(spacing: 24) {
      AsyncImage(url: viewModel.fileURL) { image in
        image
          .resizable()
          .scaledToFit()
          .frame(maxWidth: 240, maxHeight: 240)
          .clipShape(RoundedRectangle(cornerRadius: 12))
      } placeholder: {
        RoundedRectangle(cornerRadius: 12)
          .fill(.white.opacity(0.1))
          .frame(width: 240, height: 240)
          .overlay(ProgressView().tint(.white))
      }

      switch viewModel.state {
      case .editing(let memo):
        memoField(initial: memo)
        actionButtons(canSave: true)

      case .saving:
        memoFieldDisabled()
        actionButtons(canSave: false)

      case .saved:
        Text("残しました")
          .foregroundStyle(.white)

      case .failed(let message):
        memoFieldDisabled()
        Text(message)
          .font(.caption)
          .foregroundStyle(.red.opacity(0.8))
          .multilineTextAlignment(.center)
          .padding(.horizontal)
        actionButtons(canSave: true)
      }
    }
    .padding()
  }

  @ViewBuilder
  private func memoField(initial: String) -> some View {
    TextField(
      "一言（任意）",
      text: Binding(
        get: { initial },
        set: { viewModel.setMemo($0) }
      )
    )
    .textFieldStyle(.roundedBorder)
    .foregroundStyle(.black)
    .padding(.horizontal)
    .accessibilityLabel("メモ入力")
  }

  @ViewBuilder
  private func memoFieldDisabled() -> some View {
    TextField("", text: .constant(""))
      .textFieldStyle(.roundedBorder)
      .disabled(true)
      .padding(.horizontal)
      .opacity(0.4)
  }

  @ViewBuilder
  private func actionButtons(canSave: Bool) -> some View {
    HStack(spacing: 16) {
      Button {
        Task {
          await viewModel.cancel()
          onFinished()
        }
      } label: {
        Text("やめる")
          .frame(maxWidth: .infinity)
      }
      .buttonStyle(.bordered)
      .tint(.white)

      Button {
        Task { await viewModel.save() }
      } label: {
        Text("残す")
          .frame(maxWidth: .infinity)
      }
      .buttonStyle(.borderedProminent)
      .tint(.white)
      .foregroundStyle(.black)
      .disabled(!canSave)
    }
    .padding(.horizontal)
  }
}
