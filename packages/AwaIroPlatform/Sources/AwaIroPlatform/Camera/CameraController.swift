import Foundation

#if canImport(AVFoundation)
  import AVFoundation

  public protocol CameraController: Sendable {
    func start() async throws
    func stop() async
    func capture() async throws -> Data
    /// The preview layer to embed in SwiftUI via UIViewRepresentable. Main-actor
    /// access expected.
    @MainActor var previewLayer: AVCaptureVideoPreviewLayer { get }
  }

  public enum CameraControllerError: Error, Sendable {
    case noBackCamera
    case sessionConfigurationFailed
    case captureFailed(message: String)
  }

  /// AVFoundation-backed CameraController. AVCaptureSession is documented as
  /// thread-safe by Apple, so we use a final class with @unchecked Sendable
  /// rather than an actor — this lets us initialize previewLayer (@MainActor)
  /// in the init body without async hops.
  public final class AVFoundationCameraController: CameraController, @unchecked Sendable {
    private let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    @MainActor public let previewLayer: AVCaptureVideoPreviewLayer

    @MainActor
    public init() {
      self.previewLayer = AVCaptureVideoPreviewLayer()
      self.previewLayer.session = session
      self.previewLayer.videoGravity = .resizeAspectFill
    }

    public func start() async throws {
      if session.isRunning { return }
      session.beginConfiguration()
      defer { session.commitConfiguration() }

      session.sessionPreset = .photo

      guard
        let device = AVCaptureDevice.default(
          .builtInWideAngleCamera, for: .video, position: .back),
        let input = try? AVCaptureDeviceInput(device: device),
        session.canAddInput(input)
      else {
        throw CameraControllerError.noBackCamera
      }
      if session.inputs.isEmpty {
        session.addInput(input)
      }

      if session.canAddOutput(photoOutput), session.outputs.isEmpty {
        session.addOutput(photoOutput)
      }

      session.startRunning()
    }

    public func stop() async {
      if session.isRunning { session.stopRunning() }
    }

    public func capture() async throws -> Data {
      let settings = AVCapturePhotoSettings()
      let delegate = PhotoCaptureDelegate()
      photoOutput.capturePhoto(with: settings, delegate: delegate)
      return try await delegate.dataResult()
    }
  }

  private final class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate,
    @unchecked
    Sendable
  {
    private var continuation: CheckedContinuation<Data, any Error>?

    func dataResult() async throws -> Data {
      try await withCheckedThrowingContinuation { cont in
        self.continuation = cont
      }
    }

    func photoOutput(
      _ output: AVCapturePhotoOutput,
      didFinishProcessingPhoto photo: AVCapturePhoto,
      error: (any Error)?
    ) {
      if let error {
        continuation?.resume(
          throwing: CameraControllerError.captureFailed(message: String(describing: error)))
        continuation = nil
        return
      }
      guard let data = photo.fileDataRepresentation() else {
        continuation?.resume(
          throwing: CameraControllerError.captureFailed(
            message: "fileDataRepresentation returned nil"))
        continuation = nil
        return
      }
      continuation?.resume(returning: data)
      continuation = nil
    }
  }
#endif
