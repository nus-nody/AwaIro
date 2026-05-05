import AwaIroDomain
import Foundation
import Testing

@testable import AwaIroPresentation

@Suite("GalleryViewModel")
@MainActor
struct GalleryViewModelTests {

  private func makePhoto(taken: Date, id: UUID = UUID()) -> Photo {
    Photo(
      id: id, takenAt: taken, developedAt: taken.addingTimeInterval(86400),
      fileURL: URL(fileURLWithPath: "/tmp/\(id).jpg"), memo: nil)
  }

  @Test("starts in loading state")
  func initialLoading() {
    let usecase = DevelopPhotoUseCase(repository: FakeRepo(seed: []))
    let vm = GalleryViewModel(usecase: usecase)
    if case .loading = vm.state {
    } else {
      Issue.record("expected loading, got \(vm.state)")
    }
  }

  @Test("load with no photos transitions to empty")
  func loadEmpty() async {
    let usecase = DevelopPhotoUseCase(repository: FakeRepo(seed: []))
    let vm = GalleryViewModel(usecase: usecase)
    await vm.load(now: Date())
    if case .empty = vm.state {
    } else {
      Issue.record("expected empty, got \(vm.state)")
    }
  }

  @Test("load with photos transitions to loaded with current `now`")
  func loadWithPhotos() async {
    let now = Date(timeIntervalSince1970: 1_730_000_000)
    let p1 = makePhoto(taken: now.addingTimeInterval(-12 * 3600))
    let p2 = makePhoto(taken: now.addingTimeInterval(-30 * 3600))

    let usecase = DevelopPhotoUseCase(repository: FakeRepo(seed: [p2, p1]))
    let vm = GalleryViewModel(usecase: usecase)
    await vm.load(now: now)

    guard case .loaded(let photos, let asOf) = vm.state else {
      Issue.record("expected loaded, got \(vm.state)")
      return
    }
    #expect(photos.count == 2)
    #expect(photos[0].takenAt > photos[1].takenAt)
    #expect(asOf == now)
  }

  @Test("tickNow updates 'asOf' so isDeveloped flips")
  func tickUpdatesNow() async {
    let now = Date(timeIntervalSince1970: 1_730_000_000)
    let p = makePhoto(taken: now.addingTimeInterval(-23 * 3600 - 50 * 60))
    let usecase = DevelopPhotoUseCase(repository: FakeRepo(seed: [p]))
    let vm = GalleryViewModel(usecase: usecase)
    await vm.load(now: now)

    if case .loaded(let photos, _) = vm.state {
      #expect(!photos[0].isDeveloped(now: now))
    }

    let later = now.addingTimeInterval(20 * 60)
    vm.tickNow(later)

    if case .loaded(let photos, let asOf) = vm.state {
      #expect(asOf == later)
      #expect(photos[0].isDeveloped(now: asOf))
    } else {
      Issue.record("expected loaded after tick")
    }
  }

  @Test("repository failure transitions to failed")
  func loadFailed() async {
    struct Boom: Error {}
    let usecase = DevelopPhotoUseCase(repository: FailingRepo(error: Boom()))
    let vm = GalleryViewModel(usecase: usecase)
    await vm.load(now: Date())
    if case .failed = vm.state {
    } else {
      Issue.record("expected failed, got \(vm.state)")
    }
  }
}

private final class FakeRepo: PhotoRepository, @unchecked Sendable {
  private var photos: [Photo]
  init(seed: [Photo]) { self.photos = seed }
  func todayPhoto(now: Date) async throws -> Photo? { nil }
  func insert(_ photo: Photo) async throws { photos.append(photo) }
  func findAllOrderByTakenAtDesc() async throws -> [Photo] {
    photos.sorted { $0.takenAt > $1.takenAt }
  }
  func findById(_ id: UUID) async throws -> Photo? { photos.first { $0.id == id } }
  func updateMemo(id: UUID, memo: String?) async throws {}
}

private final class FailingRepo: PhotoRepository, @unchecked Sendable {
  private let error: any Error
  init(error: any Error) { self.error = error }
  func todayPhoto(now: Date) async throws -> Photo? { throw error }
  func insert(_ photo: Photo) async throws { throw error }
  func findAllOrderByTakenAtDesc() async throws -> [Photo] { throw error }
  func findById(_ id: UUID) async throws -> Photo? { throw error }
  func updateMemo(id: UUID, memo: String?) async throws { throw error }
}
