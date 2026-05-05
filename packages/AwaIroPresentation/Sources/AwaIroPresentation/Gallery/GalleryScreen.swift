import AwaIroDomain
import SwiftUI

/// State-driven content view for snapshot testing.
public struct GalleryContentView: View {
  public let state: GalleryState
  public let onTapPhoto: (UUID) -> Void
  public let onTapBack: () -> Void
  public let onTapMenu: () -> Void

  @Environment(\.skyTheme) private var theme

  public init(
    state: GalleryState,
    onTapPhoto: @escaping (UUID) -> Void = { _ in },
    onTapBack: @escaping () -> Void = {},
    onTapMenu: @escaping () -> Void = {}
  ) {
    self.state = state
    self.onTapPhoto = onTapPhoto
    self.onTapBack = onTapBack
    self.onTapMenu = onTapMenu
  }

  public var body: some View {
    ZStack {
      LinearGradient(
        colors: [theme.backgroundTop, theme.backgroundBottom],
        startPoint: .top, endPoint: .bottom
      )
      .ignoresSafeArea()

      content
    }
  }

  @ViewBuilder
  private var content: some View {
    switch state {
    case .loading:
      ProgressView().tint(theme.textPrimary)
        .accessibilityLabel("読み込み中")

    case .empty:
      VStack(spacing: 12) {
        Text("まだ泡がありません")
          .foregroundStyle(theme.textPrimary)
        Text("撮影すると、ここに泡が浮かびます")
          .font(.caption)
          .foregroundStyle(theme.textSecondary)
      }

    case .loaded(let photos, let asOf):
      ScrollView {
        LazyVStack(spacing: 32) {
          ForEach(photos, id: \.id) { photo in
            BubbleGalleryItem(photo: photo, now: asOf, size: 160)
              .onTapGesture {
                if photo.isDeveloped(now: asOf) {
                  onTapPhoto(photo.id)
                }
              }
              .accessibilityAddTraits(.isButton)
          }
        }
        .padding(.vertical, 40)
      }

    case .failed(let message):
      VStack(spacing: 12) {
        Text("読み込みに失敗しました")
          .foregroundStyle(theme.textPrimary)
        Text(message)
          .font(.caption)
          .foregroundStyle(theme.textSecondary)
      }
    }
  }
}

#if canImport(UIKit)
  /// Production GalleryScreen — composes GalleryContentView with VM lifecycle + tick timer.
  public struct GalleryScreen: View {
    @State private var viewModel: GalleryViewModel
    private let onTapPhoto: (UUID) -> Void
    private let onTapBack: () -> Void
    private let onTapMenu: () -> Void

    public init(
      viewModel: GalleryViewModel,
      onTapPhoto: @escaping (UUID) -> Void,
      onTapBack: @escaping () -> Void,
      onTapMenu: @escaping () -> Void
    ) {
      _viewModel = State(initialValue: viewModel)
      self.onTapPhoto = onTapPhoto
      self.onTapBack = onTapBack
      self.onTapMenu = onTapMenu
    }

    public var body: some View {
      GalleryContentView(
        state: viewModel.state,
        onTapPhoto: onTapPhoto,
        onTapBack: onTapBack,
        onTapMenu: onTapMenu
      )
      .overlay(alignment: .bottom) {
        BottomActionBar(
          leadingSystemName: "house.fill",
          leadingLabel: "ホーム",
          trailingSystemName: "paintpalette",
          trailingLabel: "メニュー",
          onTapLeading: onTapBack,
          onTapTrailing: onTapMenu
        )
      }
      .task {
        await viewModel.load(now: Date())
        // Tick every 60s to flip undeveloped → developed without re-querying DB.
        while !Task.isCancelled {
          try? await Task.sleep(for: .seconds(60))
          viewModel.tickNow(Date())
        }
      }
    }
  }
#endif

#if DEBUG
  #Preview("loaded — mixed") {
    let now = Date(timeIntervalSince1970: 1_730_000_000)
    GalleryContentView(
      state: .loaded(
        photos: [
          Photo(
            id: UUID(), takenAt: now.addingTimeInterval(-12 * 3600),
            developedAt: now.addingTimeInterval(12 * 3600),
            fileURL: URL(fileURLWithPath: "/tmp/a.jpg"), memo: nil),
          Photo(
            id: UUID(), takenAt: now.addingTimeInterval(-30 * 3600),
            developedAt: now.addingTimeInterval(-6 * 3600),
            fileURL: URL(fileURLWithPath: "/tmp/b.jpg"), memo: nil),
        ],
        asOf: now
      )
    )
  }

  #Preview("empty") {
    GalleryContentView(state: .empty)
  }
#endif
