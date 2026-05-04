import Foundation
import Testing

@testable import AwaIroDomain

@Suite("Photo value type")
struct PhotoTests {
  @Test("equal photos have equal hash and equality")
  func equality() {
    let id = UUID()
    let now = Date(timeIntervalSince1970: 1_730_000_000)
    let url = URL(fileURLWithPath: "/tmp/x.jpg")
    let a = Photo(id: id, takenAt: now, fileURL: url, memo: "morning walk")
    let b = Photo(id: id, takenAt: now, fileURL: url, memo: "morning walk")
    #expect(a == b)
    #expect(a.hashValue == b.hashValue)
  }

  @Test("memo is optional")
  func optionalMemo() {
    let p = Photo(id: UUID(), takenAt: Date(), fileURL: URL(fileURLWithPath: "/x.jpg"), memo: nil)
    #expect(p.memo == nil)
  }

  @Test("Codable round-trip preserves all fields")
  func codableRoundTrip() throws {
    let original = Photo(
      id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
      takenAt: Date(timeIntervalSince1970: 1_730_000_000),
      fileURL: URL(fileURLWithPath: "/tmp/x.jpg"),
      memo: "nuance"
    )
    let data = try JSONEncoder().encode(original)
    let decoded = try JSONDecoder().decode(Photo.self, from: data)
    #expect(decoded == original)
  }
}
