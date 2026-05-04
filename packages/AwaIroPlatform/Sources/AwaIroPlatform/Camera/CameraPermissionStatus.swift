import Foundation

public enum CameraPermissionStatus: Equatable, Sendable {
  case notDetermined
  case authorized
  case denied
  case restricted

  public var isUsable: Bool {
    self == .authorized
  }

  public var requiresPrompt: Bool {
    self == .notDetermined
  }
}
