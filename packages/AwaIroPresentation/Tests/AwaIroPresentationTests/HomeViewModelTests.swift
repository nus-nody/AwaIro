import AwaIroDomain
import Foundation
import Testing

@testable import AwaIroPresentation

@Suite("HomeViewModel")
struct HomeViewModelTests {
  @Test("initial state is .loading")
  @MainActor
  func initialState() {
    let vm = HomeViewModel(usecase: GetTodayPhotoUseCase(repository: StubRepo(value: nil)))
    #expect(vm.state == .loading)
  }

  @Test("load() with no today photo transitions to .unrecorded")
  @MainActor
  func loadEmpty() async {
    let vm = HomeViewModel(usecase: GetTodayPhotoUseCase(repository: StubRepo(value: nil)))
    await vm.load(now: Date())
    #expect(vm.state == .unrecorded)
  }

  @Test("load() with today photo transitions to .recorded")
  @MainActor
  func loadPresent() async {
    let now = Date()
    let photo = Photo(
      id: UUID(), takenAt: now,
      fileURL: URL(fileURLWithPath: "/tmp/x.jpg"), memo: nil
    )
    let vm = HomeViewModel(usecase: GetTodayPhotoUseCase(repository: StubRepo(value: photo)))
    await vm.load(now: now)
    #expect(vm.state == .recorded(photo))
  }

  @Test("load() error transitions to .failed")
  @MainActor
  func loadError() async {
    struct Boom: Error {}
    let vm = HomeViewModel(usecase: GetTodayPhotoUseCase(repository: StubRepo(error: Boom())))
    await vm.load(now: Date())
    if case .failed = vm.state {
      // ok
    } else {
      Issue.record("expected .failed, got \(vm.state)")
    }
  }
}

private struct StubRepo: PhotoRepository {
  let value: Photo?
  let error: (any Error)?

  init(value: Photo?) {
    self.value = value
    self.error = nil
  }
  init(error: any Error) {
    self.value = nil
    self.error = error
  }

  func todayPhoto(now: Date) async throws -> Photo? {
    if let error { throw error }
    return value
  }
  func insert(_ photo: Photo) async throws {}
}
