import Foundation
import Testing

@testable import AwaIroDomain

@Suite("Photo value type")
struct PhotoTests {
  @Test("equal photos have equal hash and equality")
  func equality() {
    let id = UUID()
    let now = Date(timeIntervalSince1970: 1_730_000_000)
    let dev = now.addingTimeInterval(86400)
    let url = URL(fileURLWithPath: "/tmp/x.jpg")
    let a = Photo(id: id, takenAt: now, developedAt: dev, fileURL: url, memo: "morning walk")
    let b = Photo(id: id, takenAt: now, developedAt: dev, fileURL: url, memo: "morning walk")
    #expect(a == b)
    #expect(a.hashValue == b.hashValue)
  }

  @Test("memo is optional")
  func optionalMemo() {
    let now = Date()
    let p = Photo(
      id: UUID(), takenAt: now, developedAt: now.addingTimeInterval(86400),
      fileURL: URL(fileURLWithPath: "/x.jpg"), memo: nil)
    #expect(p.memo == nil)
  }

  @Test("Codable round-trip preserves all fields")
  func codableRoundTrip() throws {
    let taken = Date(timeIntervalSince1970: 1_730_000_000)
    let original = Photo(
      id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
      takenAt: taken,
      developedAt: taken.addingTimeInterval(86400),
      fileURL: URL(fileURLWithPath: "/tmp/x.jpg"),
      memo: "nuance"
    )
    let data = try JSONEncoder().encode(original)
    let decoded = try JSONDecoder().decode(Photo.self, from: data)
    #expect(decoded == original)
  }

  // MARK: - G2 guardrail (翌日まで非表示)

  @Test("isDeveloped returns true exactly at developedAt boundary")
  func isDevelopedAtBoundary() {
    let taken = Date(timeIntervalSince1970: 1_730_000_000)
    let dev = taken.addingTimeInterval(86400)
    let p = Photo(
      id: UUID(), takenAt: taken, developedAt: dev,
      fileURL: URL(fileURLWithPath: "/x.jpg"), memo: nil)
    #expect(p.isDeveloped(now: dev))
  }

  @Test("isDeveloped returns false 1 second before developedAt")
  func isDevelopedJustBefore() {
    let taken = Date(timeIntervalSince1970: 1_730_000_000)
    let dev = taken.addingTimeInterval(86400)
    let just = dev.addingTimeInterval(-1)
    let p = Photo(
      id: UUID(), takenAt: taken, developedAt: dev,
      fileURL: URL(fileURLWithPath: "/x.jpg"), memo: nil)
    #expect(!p.isDeveloped(now: just))
  }

  @Test("remainingUntilDeveloped returns zero when already developed")
  func remainingZeroWhenDeveloped() {
    let taken = Date(timeIntervalSince1970: 1_730_000_000)
    let dev = taken.addingTimeInterval(86400)
    let later = dev.addingTimeInterval(3600)
    let p = Photo(
      id: UUID(), takenAt: taken, developedAt: dev,
      fileURL: URL(fileURLWithPath: "/x.jpg"), memo: nil)
    #expect(p.remainingUntilDeveloped(now: later) == 0)
  }

  @Test("remainingUntilDeveloped returns correct interval when not developed")
  func remainingWhenNotDeveloped() {
    let taken = Date(timeIntervalSince1970: 1_730_000_000)
    let dev = taken.addingTimeInterval(86400)
    let mid = taken.addingTimeInterval(43200)  // halfway
    let p = Photo(
      id: UUID(), takenAt: taken, developedAt: dev,
      fileURL: URL(fileURLWithPath: "/x.jpg"), memo: nil)
    #expect(p.remainingUntilDeveloped(now: mid) == 43200)
  }
}
