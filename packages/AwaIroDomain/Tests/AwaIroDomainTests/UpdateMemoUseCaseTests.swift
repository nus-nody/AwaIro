import Foundation
import Testing

@testable import AwaIroDomain

@Suite("UpdateMemoUseCase")
struct UpdateMemoUseCaseTests {

  @Test("updates memo on existing photo")
  func updatesExisting() async throws {
    let id = UUID()
    let now = Date(timeIntervalSince1970: 1_730_000_000)
    let p = Photo(
      id: id, takenAt: now, developedAt: now.addingTimeInterval(86400),
      fileURL: URL(fileURLWithPath: "/x"), memo: "old")

    let repo = FakeRepo(seed: [p])
    let usecase = UpdateMemoUseCase(repository: repo)

    try await usecase.execute(id: id, memo: "new")

    let updated = try await repo.findById(id)
    #expect(updated?.memo == "new")
  }

  @Test("nil memo is allowed (clearing)")
  func clearMemo() async throws {
    let id = UUID()
    let now = Date(timeIntervalSince1970: 1_730_000_000)
    let p = Photo(
      id: id, takenAt: now, developedAt: now.addingTimeInterval(86400),
      fileURL: URL(fileURLWithPath: "/x"), memo: "old")

    let repo = FakeRepo(seed: [p])
    let usecase = UpdateMemoUseCase(repository: repo)

    try await usecase.execute(id: id, memo: nil)

    let updated = try await repo.findById(id)
    #expect(updated?.memo == nil)
  }

  @Test("missing id is no-op (does not throw)")
  func missingIdNoop() async throws {
    let repo = FakeRepo(seed: [])
    let usecase = UpdateMemoUseCase(repository: repo)
    try await usecase.execute(id: UUID(), memo: "x")
  }
}

private final class FakeRepo: PhotoRepository, @unchecked Sendable {
  private var photos: [Photo]
  init(seed: [Photo]) { self.photos = seed }

  func todayPhoto(now: Date) async throws -> Photo? { nil }
  func insert(_ photo: Photo) async throws { photos.append(photo) }
  func findAllOrderByTakenAtDesc() async throws -> [Photo] { photos }
  func findById(_ id: UUID) async throws -> Photo? { photos.first { $0.id == id } }
  func updateMemo(id: UUID, memo: String?) async throws {
    if let idx = photos.firstIndex(where: { $0.id == id }) {
      let p = photos[idx]
      photos[idx] = Photo(
        id: p.id, takenAt: p.takenAt, developedAt: p.developedAt,
        fileURL: p.fileURL, memo: memo)
    }
  }
}
