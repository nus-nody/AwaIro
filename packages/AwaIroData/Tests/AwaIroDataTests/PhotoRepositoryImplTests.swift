import AwaIroDomain
import Foundation
import GRDB
import Testing

@testable import AwaIroData

@Suite("PhotoRepositoryImpl")
struct PhotoRepositoryImplTests {

  private func makeRepo() throws -> (PhotoRepositoryImpl, DatabaseQueue) {
    let queue = try DatabaseFactory.makeInMemoryQueue()
    return (PhotoRepositoryImpl(writer: queue), queue)
  }

  private func makePhoto(taken: Date, id: UUID = UUID(), memo: String? = nil) -> Photo {
    Photo(
      id: id, takenAt: taken, developedAt: taken.addingTimeInterval(86400),
      fileURL: URL(fileURLWithPath: "/tmp/\(id).jpg"), memo: memo)
  }

  @Test("todayPhoto returns nil when DB is empty")
  func emptyReturnsNil() async throws {
    let (repo, _) = try makeRepo()
    let result = try await repo.todayPhoto(now: Date())
    #expect(result == nil)
  }

  @Test("todayPhoto returns the photo recorded on the same calendar day as now")
  func sameDayReturnsPhoto() async throws {
    let (repo, _) = try makeRepo()
    let cal = Calendar.current
    let baseDay = cal.date(from: DateComponents(year: 2026, month: 5, day: 4, hour: 9))!
    let queryNow = cal.date(from: DateComponents(year: 2026, month: 5, day: 4, hour: 23))!

    let photo = makePhoto(taken: baseDay, memo: "x")
    try await repo.insert(photo)

    let result = try await repo.todayPhoto(now: queryNow)
    #expect(result == photo)
  }

  @Test("todayPhoto returns nil when only photo is from yesterday")
  func yesterdayReturnsNil() async throws {
    let (repo, _) = try makeRepo()
    let cal = Calendar.current
    let yesterday = cal.date(from: DateComponents(year: 2026, month: 5, day: 3, hour: 12))!
    let today = cal.date(from: DateComponents(year: 2026, month: 5, day: 4, hour: 12))!

    try await repo.insert(makePhoto(taken: yesterday))

    let result = try await repo.todayPhoto(now: today)
    #expect(result == nil)
  }

  @Test("insert then read preserves all fields including developedAt")
  func insertReadRoundTrip() async throws {
    let (repo, _) = try makeRepo()
    let now = Date(timeIntervalSince1970: 1_730_000_000)
    let original = makePhoto(taken: now, memo: "round-trip memo")
    try await repo.insert(original)
    let result = try await repo.todayPhoto(now: now)
    #expect(result == original)
    #expect(result?.developedAt == now.addingTimeInterval(86400))
  }

  // MARK: - New API for Phase 3

  @Test("findAllOrderByTakenAtDesc returns photos newest first")
  func findAllSorted() async throws {
    let (repo, _) = try makeRepo()
    let cal = Calendar.current
    let day1 = cal.date(from: DateComponents(year: 2026, month: 5, day: 1))!
    let day2 = cal.date(from: DateComponents(year: 2026, month: 5, day: 2))!
    let day3 = cal.date(from: DateComponents(year: 2026, month: 5, day: 3))!

    try await repo.insert(makePhoto(taken: day2))
    try await repo.insert(makePhoto(taken: day1))
    try await repo.insert(makePhoto(taken: day3))

    let all = try await repo.findAllOrderByTakenAtDesc()
    #expect(all.count == 3)
    #expect(all[0].takenAt == day3)
    #expect(all[1].takenAt == day2)
    #expect(all[2].takenAt == day1)
  }

  @Test("findAllOrderByTakenAtDesc returns empty when no photos")
  func findAllEmpty() async throws {
    let (repo, _) = try makeRepo()
    let all = try await repo.findAllOrderByTakenAtDesc()
    #expect(all.isEmpty)
  }

  @Test("findById returns the matching photo")
  func findByIdMatches() async throws {
    let (repo, _) = try makeRepo()
    let id = UUID()
    let now = Date(timeIntervalSince1970: 1_730_000_000)
    try await repo.insert(makePhoto(taken: now, id: id, memo: "find me"))

    let result = try await repo.findById(id)
    #expect(result?.id == id)
    #expect(result?.memo == "find me")
  }

  @Test("findById returns nil for unknown id")
  func findByIdMissing() async throws {
    let (repo, _) = try makeRepo()
    let result = try await repo.findById(UUID())
    #expect(result == nil)
  }

  @Test("updateMemo replaces memo for existing photo")
  func updateMemoReplaces() async throws {
    let (repo, _) = try makeRepo()
    let id = UUID()
    let now = Date(timeIntervalSince1970: 1_730_000_000)
    try await repo.insert(makePhoto(taken: now, id: id, memo: "old"))

    try await repo.updateMemo(id: id, memo: "new")

    let result = try await repo.findById(id)
    #expect(result?.memo == "new")
  }

  @Test("updateMemo nil clears memo")
  func updateMemoClears() async throws {
    let (repo, _) = try makeRepo()
    let id = UUID()
    let now = Date(timeIntervalSince1970: 1_730_000_000)
    try await repo.insert(makePhoto(taken: now, id: id, memo: "old"))

    try await repo.updateMemo(id: id, memo: nil)

    let result = try await repo.findById(id)
    #expect(result?.memo == nil)
  }

  @Test("updateMemo on missing id is a no-op")
  func updateMemoNoop() async throws {
    let (repo, _) = try makeRepo()
    try await repo.updateMemo(id: UUID(), memo: "x")  // should not throw
  }
}
