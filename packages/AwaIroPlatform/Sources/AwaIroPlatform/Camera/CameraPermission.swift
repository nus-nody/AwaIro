import Foundation

public protocol CameraPermission: Sendable {
  /// Current permission status — synchronous (no prompt).
  func currentStatus() async -> CameraPermissionStatus

  /// If the current status is .notDetermined, prompts the user and
  /// returns the resulting status. If already determined, returns it
  /// without re-prompting.
  func requestIfNeeded() async -> CameraPermissionStatus
}

#if canImport(AVFoundation)
  import AVFoundation

  public struct AVFoundationCameraPermission: CameraPermission {
    public init() {}

    public func currentStatus() async -> CameraPermissionStatus {
      Self.translate(AVCaptureDevice.authorizationStatus(for: .video))
    }

    public func requestIfNeeded() async -> CameraPermissionStatus {
      let current = AVCaptureDevice.authorizationStatus(for: .video)
      if current != .notDetermined {
        return Self.translate(current)
      }
      let granted = await AVCaptureDevice.requestAccess(for: .video)
      return granted ? .authorized : .denied
    }

    private static func translate(_ status: AVAuthorizationStatus) -> CameraPermissionStatus {
      switch status {
      case .notDetermined: return .notDetermined
      case .authorized: return .authorized
      case .denied: return .denied
      case .restricted: return .restricted
      @unknown default: return .denied
      }
    }
  }
#endif
