import Foundation

public protocol PhotoRepository: Sendable {
  /// Fetches the photo recorded on the same calendar day (device local) as `now`.
  /// Returns nil if no photo recorded today.
  func todayPhoto(now: Date) async throws -> Photo?

  /// Inserts a new photo. Assumes caller has already enforced "1日1枚" guardrail (G1) at use case level.
  func insert(_ photo: Photo) async throws

  /// Returns all photos ordered by `takenAt` descending (newest first).
  func findAllOrderByTakenAtDesc() async throws -> [Photo]

  /// Returns the photo with the given id, or nil if not found.
  func findById(_ id: UUID) async throws -> Photo?

  /// Updates the memo for the photo with the given id. No-op if id not found.
  func updateMemo(id: UUID, memo: String?) async throws
}
