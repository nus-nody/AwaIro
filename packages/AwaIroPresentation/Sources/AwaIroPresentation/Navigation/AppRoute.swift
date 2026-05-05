import Foundation

public enum AppRoute: Hashable, Sendable {
  /// Captured photo, awaiting memo input and save.
  case memo(fileURL: URL, takenAt: Date)
  /// Bubble gallery — vertical scroll of bubbles.
  case gallery
  /// Photo detail screen — fullscreen photo + memo, swipeable.
  case photoDetail(photoId: UUID)
}
