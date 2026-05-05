import Foundation
import Testing

@testable import AwaIroDomain

@Suite("GetTodayPhotoUseCase")
struct GetTodayPhotoUseCaseTests {
  @Test("returns nil when repository has no photo today")
  func returnsNilWhenEmpty() async throws {
    let repo = StubPhotoRepository(todayPhoto: nil)
    let usecase = GetTodayPhotoUseCase(repository: repo)
    let result = try await usecase.execute(now: Date())
    #expect(result == nil)
  }

  @Test("returns the photo when repository has one")
  func returnsPhotoWhenPresent() async throws {
    let now = Date(timeIntervalSince1970: 1_730_000_000)
    let photo = Photo(
      id: UUID(),
      takenAt: now,
      developedAt: now.addingTimeInterval(86400),
      fileURL: URL(fileURLWithPath: "/tmp/today.jpg"),
      memo: nil
    )
    let repo = StubPhotoRepository(todayPhoto: photo)
    let usecase = GetTodayPhotoUseCase(repository: repo)
    let result = try await usecase.execute(now: now)
    #expect(result == photo)
  }

  @Test("propagates repository errors")
  func propagatesError() async {
    struct Boom: Error {}
    let repo = StubPhotoRepository(error: Boom())
    let usecase = GetTodayPhotoUseCase(repository: repo)
    await #expect(throws: Boom.self) {
      _ = try await usecase.execute(now: Date())
    }
  }
}

private struct StubPhotoRepository: PhotoRepository {
  let todayPhotoValue: Photo?
  let throwError: (any Error)?

  init(todayPhoto: Photo?) {
    self.todayPhotoValue = todayPhoto
    self.throwError = nil
  }

  init(error: any Error) {
    self.todayPhotoValue = nil
    self.throwError = error
  }

  func todayPhoto(now: Date) async throws -> Photo? {
    if let throwError { throw throwError }
    return todayPhotoValue
  }

  func insert(_ photo: Photo) async throws {
    // Not used in these tests
  }
}
