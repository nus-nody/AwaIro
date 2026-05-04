import Foundation

public enum AppRoute: Hashable, Sendable {
  /// Captured photo, awaiting memo input and save.
  case memo(fileURL: URL, takenAt: Date)
}
