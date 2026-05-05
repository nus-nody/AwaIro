import Foundation
import Testing

@testable import AwaIroDomain

@Suite("DevelopPhotoUseCase — G2 (翌日まで非表示)")
struct DevelopPhotoUseCaseTests {

  private func makePhoto(taken: Date, id: String = "11111111-1111-1111-1111-111111111111") -> Photo
  {
    Photo(
      id: UUID(uuidString: id)!,
      takenAt: taken,
      developedAt: taken.addingTimeInterval(86400),
      fileURL: URL(fileURLWithPath: "/tmp/\(id).jpg"),
      memo: nil
    )
  }

  @Test("returns all photos ordered by takenAt desc")
  func returnsAllSorted() async throws {
    let cal = Calendar.current
    let day1 = cal.date(from: DateComponents(year: 2026, month: 5, day: 1))!
    let day2 = cal.date(from: DateComponents(year: 2026, month: 5, day: 2))!
    let day3 = cal.date(from: DateComponents(year: 2026, month: 5, day: 3))!

    let repo = FakeRepo()
    try await repo.insert(makePhoto(taken: day2, id: "22222222-2222-2222-2222-222222222222"))
    try await repo.insert(makePhoto(taken: day1, id: "11111111-1111-1111-1111-111111111111"))
    try await repo.insert(makePhoto(taken: day3, id: "33333333-3333-3333-3333-333333333333"))

    let usecase = DevelopPhotoUseCase(repository: repo)
    let photos = try await usecase.execute()

    #expect(photos.count == 3)
    #expect(photos[0].takenAt == day3)
    #expect(photos[1].takenAt == day2)
    #expect(photos[2].takenAt == day1)
  }

  @Test("photo taken 23h ago is NOT developed (G2)")
  func notDevelopedWithin24h() async throws {
    let now = Date(timeIntervalSince1970: 1_730_000_000)
    let taken = now.addingTimeInterval(-23 * 3600)

    let repo = FakeRepo()
    try await repo.insert(makePhoto(taken: taken))

    let usecase = DevelopPhotoUseCase(repository: repo)
    let photos = try await usecase.execute()

    #expect(photos.count == 1)
    #expect(!photos[0].isDeveloped(now: now))
  }

  @Test("photo taken 25h ago IS developed (G2)")
  func developedAfter24h() async throws {
    let now = Date(timeIntervalSince1970: 1_730_000_000)
    let taken = now.addingTimeInterval(-25 * 3600)

    let repo = FakeRepo()
    try await repo.insert(makePhoto(taken: taken))

    let usecase = DevelopPhotoUseCase(repository: repo)
    let photos = try await usecase.execute()

    #expect(photos.count == 1)
    #expect(photos[0].isDeveloped(now: now))
  }

  @Test("empty repository returns empty list")
  func emptyReturnsEmpty() async throws {
    let repo = FakeRepo()
    let usecase = DevelopPhotoUseCase(repository: repo)
    let photos = try await usecase.execute()
    #expect(photos.isEmpty)
  }
}

private final class FakeRepo: PhotoRepository, @unchecked Sendable {
  private var photos: [Photo] = []

  func todayPhoto(now: Date) async throws -> Photo? { nil }
  func insert(_ photo: Photo) async throws { photos.append(photo) }
  func findAllOrderByTakenAtDesc() async throws -> [Photo] {
    photos.sorted { $0.takenAt > $1.takenAt }
  }
  func findById(_ id: UUID) async throws -> Photo? { photos.first { $0.id == id } }
  func updateMemo(id: UUID, memo: String?) async throws {}
}
