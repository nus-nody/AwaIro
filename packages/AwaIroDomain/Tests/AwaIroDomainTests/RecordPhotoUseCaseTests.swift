import Foundation
import Testing

@testable import AwaIroDomain

@Suite("RecordPhotoUseCase — G1 (1日1枚)")
struct RecordPhotoUseCaseTests {

  @Test("inserts when no photo exists for today")
  func insertsWhenEmpty() async throws {
    let repo = FakePhotoRepository()
    let usecase = RecordPhotoUseCase(repository: repo)

    let now = Date(timeIntervalSince1970: 1_730_000_000)
    let url = URL(fileURLWithPath: "/tmp/x.jpg")

    let saved = try await usecase.execute(fileURL: url, takenAt: now, memo: "morning")

    #expect(saved.fileURL == url)
    #expect(saved.takenAt == now)
    #expect(saved.memo == "morning")
    #expect(repo.inserted.count == 1)
  }

  @Test("refuses second photo on the same calendar day")
  func refusesSameDay() async throws {
    let repo = FakePhotoRepository()
    let usecase = RecordPhotoUseCase(repository: repo)
    let cal = Calendar.current

    let morning = cal.date(from: DateComponents(year: 2026, month: 5, day: 4, hour: 9))!
    _ = try await usecase.execute(
      fileURL: URL(fileURLWithPath: "/tmp/a.jpg"), takenAt: morning, memo: nil)

    let evening = cal.date(from: DateComponents(year: 2026, month: 5, day: 4, hour: 23))!
    await #expect(throws: RecordPhotoError.alreadyRecordedToday) {
      _ = try await usecase.execute(
        fileURL: URL(fileURLWithPath: "/tmp/b.jpg"), takenAt: evening, memo: nil)
    }

    #expect(repo.inserted.count == 1)
  }

  @Test("accepts photo on next calendar day")
  func acceptsNextDay() async throws {
    let repo = FakePhotoRepository()
    let usecase = RecordPhotoUseCase(repository: repo)
    let cal = Calendar.current

    let day1 = cal.date(from: DateComponents(year: 2026, month: 5, day: 4, hour: 12))!
    _ = try await usecase.execute(
      fileURL: URL(fileURLWithPath: "/tmp/a.jpg"), takenAt: day1, memo: nil)

    let day2 = cal.date(from: DateComponents(year: 2026, month: 5, day: 5, hour: 12))!
    let saved2 = try await usecase.execute(
      fileURL: URL(fileURLWithPath: "/tmp/b.jpg"), takenAt: day2, memo: "next")

    #expect(saved2.memo == "next")
    #expect(repo.inserted.count == 2)
  }

  @Test("accepts midnight-crossing as a new day (23:59 then 00:00)")
  func acceptsMidnightCrossing() async throws {
    let repo = FakePhotoRepository()
    let usecase = RecordPhotoUseCase(repository: repo)
    let cal = Calendar.current

    let dec31 = cal.date(
      from: DateComponents(year: 2025, month: 12, day: 31, hour: 23, minute: 59))!
    _ = try await usecase.execute(
      fileURL: URL(fileURLWithPath: "/tmp/a.jpg"), takenAt: dec31, memo: nil)

    let jan1 = cal.date(from: DateComponents(year: 2026, month: 1, day: 1, hour: 0, minute: 0))!
    let saved2 = try await usecase.execute(
      fileURL: URL(fileURLWithPath: "/tmp/b.jpg"), takenAt: jan1, memo: nil)

    #expect(saved2.takenAt == jan1)
    #expect(repo.inserted.count == 2)
  }

  @Test("forwards repository failure as repositoryFailure")
  func forwardsRepositoryError() async {
    struct Boom: Error {}
    let repo = FakePhotoRepository(insertError: Boom())
    let usecase = RecordPhotoUseCase(repository: repo)

    await #expect(throws: RecordPhotoError.self) {
      _ = try await usecase.execute(
        fileURL: URL(fileURLWithPath: "/tmp/x.jpg"), takenAt: Date(), memo: nil)
    }
  }
}

private final class FakePhotoRepository: PhotoRepository, @unchecked Sendable {
  private(set) var inserted: [Photo] = []
  private let insertError: (any Error)?

  init(insertError: (any Error)? = nil) {
    self.insertError = insertError
  }

  func todayPhoto(now: Date) async throws -> Photo? {
    let cal = Calendar.current
    let startOfDay = cal.startOfDay(for: now)
    let endOfDay = cal.date(byAdding: .day, value: 1, to: startOfDay)!
    return inserted.first { $0.takenAt >= startOfDay && $0.takenAt < endOfDay }
  }

  func insert(_ photo: Photo) async throws {
    if let insertError {
      throw RecordPhotoError.repositoryFailure(message: String(describing: insertError))
    }
    inserted.append(photo)
  }

  func findAllOrderByTakenAtDesc() async throws -> [Photo] {
    inserted.sorted { $0.takenAt > $1.takenAt }
  }
  func findById(_ id: UUID) async throws -> Photo? { inserted.first { $0.id == id } }
  func updateMemo(id: UUID, memo: String?) async throws {}
}
