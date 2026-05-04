import Foundation

public struct Photo: Hashable, Codable, Sendable {
  public let id: UUID
  public let takenAt: Date
  public let fileURL: URL
  public let memo: String?

  public init(id: UUID, takenAt: Date, fileURL: URL, memo: String?) {
    self.id = id
    self.takenAt = takenAt
    self.fileURL = fileURL
    self.memo = memo
  }
}
