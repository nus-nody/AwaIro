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

    let photo = Photo(
      id: UUID(),
      takenAt: baseDay,
      fileURL: URL(fileURLWithPath: "/tmp/x.jpg"),
      memo: "x"
    )
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

    try await repo.insert(
      Photo(
        id: UUID(), takenAt: yesterday,
        fileURL: URL(fileURLWithPath: "/tmp/y.jpg"), memo: nil
      ))

    let result = try await repo.todayPhoto(now: today)
    #expect(result == nil)
  }

  @Test("insert then read preserves all fields")
  func insertReadRoundTrip() async throws {
    let (repo, _) = try makeRepo()
    let now = Date(timeIntervalSince1970: 1_730_000_000)
    let original = Photo(
      id: UUID(),
      takenAt: now,
      fileURL: URL(fileURLWithPath: "/tmp/round.jpg"),
      memo: "round-trip memo"
    )
    try await repo.insert(original)
    let result = try await repo.todayPhoto(now: now)
    #expect(result == original)
  }
}
