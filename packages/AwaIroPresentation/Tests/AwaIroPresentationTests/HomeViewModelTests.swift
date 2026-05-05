import AwaIroDomain
import AwaIroPlatform
import Foundation
import Testing

@testable import AwaIroPresentation

@Suite("HomeViewModel")
struct HomeViewModelTests {
  @Test("initial state is .loading")
  @MainActor
  func initialState() {
    let vm = HomeViewModel(
      usecase: GetTodayPhotoUseCase(repository: StubRepo(value: nil)),
      cameraPermission: FakePermission(initial: .authorized),
      capturePhotoData: { Data() },
      photoFileStore: PhotoFileStore(filePathProvider: tempProvider())
    )
    #expect(vm.state == .loading)
  }

  @Test("load() with no today photo transitions to .unrecorded")
  @MainActor
  func loadEmpty() async {
    let vm = HomeViewModel(
      usecase: GetTodayPhotoUseCase(repository: StubRepo(value: nil)),
      cameraPermission: FakePermission(initial: .authorized),
      capturePhotoData: { Data() },
      photoFileStore: PhotoFileStore(filePathProvider: tempProvider())
    )
    await vm.load(now: Date())
    #expect(vm.state == .unrecorded)
  }

  @Test("load() with today photo transitions to .recorded")
  @MainActor
  func loadPresent() async {
    let now = Date()
    let photo = Photo(
      id: UUID(), takenAt: now,
      developedAt: now.addingTimeInterval(86400),
      fileURL: URL(fileURLWithPath: "/tmp/x.jpg"), memo: nil
    )
    let vm = HomeViewModel(
      usecase: GetTodayPhotoUseCase(repository: StubRepo(value: photo)),
      cameraPermission: FakePermission(initial: .authorized),
      capturePhotoData: { Data() },
      photoFileStore: PhotoFileStore(filePathProvider: tempProvider())
    )
    await vm.load(now: now)
    #expect(vm.state == .recorded(photo))
  }

  @Test("load() error transitions to .failed")
  @MainActor
  func loadError() async {
    struct Boom: Error {}
    let vm = HomeViewModel(
      usecase: GetTodayPhotoUseCase(repository: StubRepo(error: Boom())),
      cameraPermission: FakePermission(initial: .authorized),
      capturePhotoData: { Data() },
      photoFileStore: PhotoFileStore(filePathProvider: tempProvider())
    )
    await vm.load(now: Date())
    if case .failed = vm.state {
      // ok
    } else {
      Issue.record("expected .failed, got \(vm.state)")
    }
  }

  @Test("permission starts at .notDetermined")
  @MainActor
  func permissionInitial() {
    let vm = HomeViewModel(
      usecase: GetTodayPhotoUseCase(repository: StubRepo(value: nil)),
      cameraPermission: FakePermission(initial: .notDetermined),
      capturePhotoData: { Data() },
      photoFileStore: PhotoFileStore(filePathProvider: tempProvider())
    )
    #expect(vm.permission == .notDetermined)
  }

  @Test("requestCameraIfNeeded prompts when notDetermined and updates permission")
  @MainActor
  func requestPrompts() async {
    let perm = FakePermission(initial: .notDetermined, willGrant: true)
    let vm = HomeViewModel(
      usecase: GetTodayPhotoUseCase(repository: StubRepo(value: nil)),
      cameraPermission: perm,
      capturePhotoData: { Data() },
      photoFileStore: PhotoFileStore(filePathProvider: tempProvider())
    )
    await vm.requestCameraIfNeeded()
    #expect(vm.permission == .authorized)
    #expect(perm.requestCount == 1)
  }

  @Test("requestCameraIfNeeded does not re-prompt when already authorized")
  @MainActor
  func requestSkipsWhenAuthorized() async {
    let perm = FakePermission(initial: .authorized)
    let vm = HomeViewModel(
      usecase: GetTodayPhotoUseCase(repository: StubRepo(value: nil)),
      cameraPermission: perm,
      capturePhotoData: { Data() },
      photoFileStore: PhotoFileStore(filePathProvider: tempProvider())
    )
    await vm.requestCameraIfNeeded()
    #expect(perm.requestCount == 0)
    #expect(vm.permission == .authorized)
  }

  @Test("capturePhoto returns a URL after writing JPEG to file store")
  @MainActor
  func capturePhotoWritesFile() async throws {
    let captureData = Data([0xFF, 0xD8, 0xFF, 0xE0])
    let provider = tempProvider()
    let store = PhotoFileStore(filePathProvider: provider)
    let vm = HomeViewModel(
      usecase: GetTodayPhotoUseCase(repository: StubRepo(value: nil)),
      cameraPermission: FakePermission(initial: .authorized),
      capturePhotoData: { captureData },
      photoFileStore: store
    )
    let url = await vm.capturePhoto()
    let url2 = try #require(url)
    #expect(url2.path.hasPrefix(provider.photoDirectory.path))
    let read = try Data(contentsOf: url2)
    #expect(read == captureData)
  }
}

// Test helpers

private func tempProvider() -> FilePathProvider {
  FilePathProvider(
    rootDirectory:
      FileManager.default.temporaryDirectory
      .appendingPathComponent("awairo-vm-test-\(UUID().uuidString)"))
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
  func findAllOrderByTakenAtDesc() async throws -> [Photo] { value.map { [$0] } ?? [] }
  func findById(_ id: UUID) async throws -> Photo? { value?.id == id ? value : nil }
  func updateMemo(id: UUID, memo: String?) async throws {}
}

private final class FakePermission: CameraPermission, @unchecked Sendable {
  private(set) var requestCount = 0
  private var status: CameraPermissionStatus
  private let willGrant: Bool

  init(initial: CameraPermissionStatus, willGrant: Bool = false) {
    self.status = initial
    self.willGrant = willGrant
  }

  func currentStatus() async -> CameraPermissionStatus { status }

  func requestIfNeeded() async -> CameraPermissionStatus {
    if status == .notDetermined {
      requestCount += 1
      status = willGrant ? .authorized : .denied
    }
    return status
  }
}
