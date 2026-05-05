import Foundation

public struct Photo: Hashable, Codable, Sendable {
  public let id: UUID
  public let takenAt: Date
  public let developedAt: Date
  public let fileURL: URL
  public let memo: String?

  public init(id: UUID, takenAt: Date, developedAt: Date, fileURL: URL, memo: String?) {
    self.id = id
    self.takenAt = takenAt
    self.developedAt = developedAt
    self.fileURL = fileURL
    self.memo = memo
  }

  /// G2 guardrail: a photo is "developed" only at or after `developedAt`.
  public func isDeveloped(now: Date) -> Bool {
    now >= developedAt
  }

  /// Seconds until developed. Zero if already developed.
  public func remainingUntilDeveloped(now: Date) -> TimeInterval {
    isDeveloped(now: now) ? 0 : developedAt.timeIntervalSince(now)
  }
}
