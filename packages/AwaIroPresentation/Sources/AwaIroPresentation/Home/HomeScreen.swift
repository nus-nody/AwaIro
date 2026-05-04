import AwaIroDomain
import AwaIroPlatform
import SwiftUI

/// State-driven content view — parameterized over the bubble placeholder so
/// snapshot tests can inject a static stand-in instead of the live camera.
struct HomeContentView<Bubble: View>: View {
  let state: HomeState
  let permission: CameraPermissionStatus
  let bubble: () -> Bubble
  let onRequestPermission: () -> Void

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
      switch permission {
      case .authorized:
        bubble()
      case .notDetermined:
        Button(action: onRequestPermission) {
          Text("カメラへのアクセスを許可")
            .padding()
            .foregroundStyle(.white)
        }
        .buttonStyle(.bordered)
        .tint(.white)
        .accessibilityHint("カメラを使うには許可が要ります")
      case .denied, .restricted:
        VStack(spacing: 12) {
          Text("カメラがオフになっています")
            .foregroundStyle(.white)
          Text("設定アプリからカメラを許可してください")
            .font(.caption)
            .foregroundStyle(.white.opacity(0.6))
            .multilineTextAlignment(.center)
        }
      }

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

#if canImport(UIKit) && canImport(AVFoundation)
  import AVFoundation

  /// Production HomeScreen — composes HomeContentView with a live BubbleCameraView.
  public struct HomeScreen: View {
    @State private var viewModel: HomeViewModel
    private let camera: any CameraController
    private let onCaptured: @MainActor (URL, Date) -> Void

    public init(
      viewModel: HomeViewModel,
      camera: any CameraController,
      onCaptured: @escaping @MainActor (URL, Date) -> Void
    ) {
      _viewModel = State(initialValue: viewModel)
      self.camera = camera
      self.onCaptured = onCaptured
    }

    public var body: some View {
      HomeContentView(
        state: viewModel.state,
        permission: viewModel.permission,
        bubble: {
          BubbleCameraView(camera: camera) {
            let takenAt = Date()
            if let url = await viewModel.capturePhoto() {
              await onCaptured(url, takenAt)
            }
          }
        },
        onRequestPermission: {
          Task { await viewModel.requestCameraIfNeeded() }
        }
      )
      .task {
        await viewModel.load(now: Date())
      }
    }
  }
#endif

#if DEBUG
  #Preview("unrecorded + authorized (placeholder bubble)") {
    HomeContentView(
      state: .unrecorded,
      permission: .authorized,
      bubble: { Circle().fill(.white.opacity(0.85)).frame(width: 280, height: 280) },
      onRequestPermission: {}
    )
  }

  #Preview("notDetermined") {
    HomeContentView(
      state: .unrecorded,
      permission: .notDetermined,
      bubble: { EmptyView() },
      onRequestPermission: {}
    )
  }

  #Preview("denied") {
    HomeContentView(
      state: .unrecorded,
      permission: .denied,
      bubble: { EmptyView() },
      onRequestPermission: {}
    )
  }

  #Preview("recorded") {
    HomeContentView(
      state: .recorded(
        Photo(
          id: UUID(),
          takenAt: Date(),
          fileURL: URL(fileURLWithPath: "/tmp/preview.jpg"),
          memo: "preview"
        )),
      permission: .authorized,
      bubble: { EmptyView() },
      onRequestPermission: {}
    )
  }
#endif
