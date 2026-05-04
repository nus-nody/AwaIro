#if canImport(UIKit) && canImport(AVFoundation)
  import SwiftUI
  import UIKit
  import AVFoundation
  import AwaIroPlatform

  public struct BubbleCameraView: View {
    private let camera: any CameraController
    private let radius: CGFloat
    private let onTapCapture: @Sendable () async -> Void

    public init(
      camera: any CameraController,
      radius: CGFloat = 140,
      onTapCapture: @escaping @Sendable () async -> Void
    ) {
      self.camera = camera
      self.radius = radius
      self.onTapCapture = onTapCapture
    }

    public var body: some View {
      CameraPreviewRepresentable(camera: camera)
        .frame(width: radius * 2, height: radius * 2)
        .clipShape(Circle())
        .bubbleDistortion(radius: radius)
        .contentShape(Circle())
        .onTapGesture {
          Task { await onTapCapture() }
        }
        .task {
          do {
            try await camera.start()
          } catch {
            print("CameraController.start failed: \(error)")
          }
        }
        .onDisappear {
          Task { await camera.stop() }
        }
        .accessibilityLabel("泡をタップして撮影")
        .accessibilityAddTraits(SwiftUI.AccessibilityTraits.isButton)
    }
  }

  private struct CameraPreviewRepresentable: UIViewRepresentable {
    let camera: any CameraController

    @MainActor
    func makeUIView(context: Context) -> CameraPreviewUIView {
      let view = CameraPreviewUIView()
      view.previewLayer = camera.previewLayer
      return view
    }

    @MainActor
    func updateUIView(_ uiView: CameraPreviewUIView, context: Context) {
      uiView.previewLayer = camera.previewLayer
    }
  }

  @MainActor
  private final class CameraPreviewUIView: UIView {
    override init(frame: CGRect) {
      super.init(frame: frame)
      backgroundColor = .black
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) not used") }

    var previewLayer: AVCaptureVideoPreviewLayer? {
      didSet {
        if let oldValue { oldValue.removeFromSuperlayer() }
        if let previewLayer {
          previewLayer.frame = bounds
          layer.addSublayer(previewLayer)
        }
      }
    }

    override func layoutSubviews() {
      super.layoutSubviews()
      previewLayer?.frame = bounds
    }
  }
#endif
