import Foundation

public protocol PhotoRepository: Sendable {
  /// Fetches the photo recorded on the same calendar day (device local) as `now`.
  /// Returns nil if no photo recorded today.
  func todayPhoto(now: Date) async throws -> Photo?

  /// Inserts a new photo. Assumes caller has already enforced "1日1枚" guardrail (G1) at use case level.
  func insert(_ photo: Photo) async throws
}
