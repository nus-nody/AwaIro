import AwaIroDomain
import SwiftUI

public struct PhotoDetailContentView: View {
  public let state: PhotoDetailState
  public let onStartEdit: () -> Void
  public let onCancelEdit: () -> Void
  public let onSetDraft: (String) -> Void
  public let onSave: () -> Void
  public let onTapShare: () -> Void

  @Environment(\.skyTheme) private var theme

  public init(
    state: PhotoDetailState,
    onStartEdit: @escaping () -> Void = {},
    onCancelEdit: @escaping () -> Void = {},
    onSetDraft: @escaping (String) -> Void = { _ in },
    onSave: @escaping () -> Void = {},
    onTapShare: @escaping () -> Void = {}
  ) {
    self.state = state
    self.onStartEdit = onStartEdit
    self.onCancelEdit = onCancelEdit
    self.onSetDraft = onSetDraft
    self.onSave = onSave
    self.onTapShare = onTapShare
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

  private var photo: Photo {
    switch state {
    case .viewing(let p), .editing(let p, _), .saving(let p), .failed(let p, _): return p
    }
  }

  @ViewBuilder
  private var content: some View {
    VStack(spacing: 24) {
      AsyncImage(url: photo.fileURL) { image in
        image
          .resizable()
          .scaledToFit()
          .clipShape(RoundedRectangle(cornerRadius: 16))
      } placeholder: {
        RoundedRectangle(cornerRadius: 16)
          .fill(.white.opacity(0.08))
          .overlay(ProgressView().tint(theme.textPrimary))
      }
      .frame(maxHeight: .infinity)
      .padding(.horizontal)

      memoSection

      // Share placeholder (Sprint 3 implements actual share)
      Button(action: onTapShare) {
        Label("シェア", systemImage: "square.and.arrow.up")
          .foregroundStyle(theme.textPrimary)
      }
      .buttonStyle(.bordered)
      .tint(theme.textPrimary)
      .accessibilityHint("Sprint 3 で実装予定")
      .padding(.bottom)
    }
  }

  @ViewBuilder
  private var memoSection: some View {
    switch state {
    case .viewing(let p):
      HStack(alignment: .top) {
        Text(p.memo ?? "メモなし")
          .foregroundStyle(p.memo == nil ? theme.textSecondary : theme.textPrimary)
          .frame(maxWidth: .infinity, alignment: .leading)
        Button(action: onStartEdit) {
          Image(systemName: "pencil")
        }
        .foregroundStyle(theme.textPrimary)
        .accessibilityLabel("メモを編集")
      }
      .padding(.horizontal)

    case .editing(_, let draft):
      VStack(spacing: 8) {
        TextField(
          "一言（任意）",
          text: Binding(get: { draft }, set: { onSetDraft($0) })
        )
        .textFieldStyle(.roundedBorder)
        .accessibilityLabel("メモ入力")

        HStack(spacing: 16) {
          Button("やめる", action: onCancelEdit)
            .buttonStyle(.bordered)
          Button("保存", action: onSave)
            .buttonStyle(.borderedProminent)
        }
      }
      .padding(.horizontal)

    case .saving:
      ProgressView()
        .tint(theme.textPrimary)
        .padding()

    case .failed(_, let message):
      VStack(spacing: 8) {
        Text(message)
          .font(.caption)
          .foregroundStyle(.red)
          .multilineTextAlignment(.center)
        Button("やめる", action: onCancelEdit)
          .buttonStyle(.bordered)
      }
      .padding(.horizontal)
    }
  }
}

#if canImport(UIKit)
  /// PhotoDetailScreen — fullscreen viewer with TabView pager (left/right swipe).
  public struct PhotoDetailScreen: View {
    @State private var viewModels: [UUID: PhotoDetailViewModel]
    private let photos: [Photo]
    @State private var selectedId: UUID

    public init(
      photos: [Photo],
      initialPhotoId: UUID,
      updateMemoFactory: @escaping (Photo) -> PhotoDetailViewModel
    ) {
      self.photos = photos
      self._selectedId = State(initialValue: initialPhotoId)
      var initial: [UUID: PhotoDetailViewModel] = [:]
      for p in photos { initial[p.id] = updateMemoFactory(p) }
      self._viewModels = State(initialValue: initial)
    }

    public var body: some View {
      TabView(selection: $selectedId) {
        ForEach(photos, id: \.id) { photo in
          PhotoDetailContentView(
            state: viewModels[photo.id]?.state ?? .viewing(photo),
            onStartEdit: { viewModels[photo.id]?.startEditing() },
            onCancelEdit: { viewModels[photo.id]?.cancelEditing() },
            onSetDraft: { viewModels[photo.id]?.setDraft($0) },
            onSave: { Task { await viewModels[photo.id]?.save() } },
            onTapShare: {}
          )
          .tag(photo.id)
        }
      }
      .tabViewStyle(.page(indexDisplayMode: .never))
    }
  }
#endif

#if DEBUG
  #Preview("viewing — with memo") {
    let now = Date(timeIntervalSince1970: 1_730_000_000)
    PhotoDetailContentView(
      state: .viewing(
        Photo(
          id: UUID(), takenAt: now,
          developedAt: now.addingTimeInterval(-3600),
          fileURL: URL(fileURLWithPath: "/tmp/x.jpg"), memo: "朝の散歩"
        ))
    )
  }

  #Preview("viewing — empty memo") {
    let now = Date(timeIntervalSince1970: 1_730_000_000)
    PhotoDetailContentView(
      state: .viewing(
        Photo(
          id: UUID(), takenAt: now,
          developedAt: now.addingTimeInterval(-3600),
          fileURL: URL(fileURLWithPath: "/tmp/x.jpg"), memo: nil
        ))
    )
  }

  #Preview("editing") {
    let now = Date(timeIntervalSince1970: 1_730_000_000)
    PhotoDetailContentView(
      state: .editing(
        Photo(
          id: UUID(), takenAt: now,
          developedAt: now.addingTimeInterval(-3600),
          fileURL: URL(fileURLWithPath: "/tmp/x.jpg"), memo: "前のメモ"),
        draft: "編集中のメモ"
      )
    )
  }
#endif
