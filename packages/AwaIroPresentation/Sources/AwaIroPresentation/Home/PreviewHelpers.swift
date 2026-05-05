#if DEBUG
  import Foundation
  import AwaIroDomain
  import AwaIroPlatform

  @MainActor
  public enum PreviewHelpers {
    public static func unrecordedVM() -> HomeViewModel {
      HomeViewModel(
        usecase: GetTodayPhotoUseCase(repository: AlwaysEmptyRepo()),
        cameraPermission: AlwaysAuthorizedPermission(),
        capturePhotoData: { Data() },
        photoFileStore: PhotoFileStore(filePathProvider: previewProvider())
      )
    }

    public static func recordedVM() -> HomeViewModel {
      let takenAt = Date()
      let photo = Photo(
        id: UUID(),
        takenAt: takenAt,
        developedAt: takenAt.addingTimeInterval(86400),
        fileURL: URL(fileURLWithPath: "/tmp/preview.jpg"),
        memo: "preview"
      )
      return HomeViewModel(
        usecase: GetTodayPhotoUseCase(repository: AlwaysReturnRepo(photo: photo)),
        cameraPermission: AlwaysAuthorizedPermission(),
        capturePhotoData: { Data() },
        photoFileStore: PhotoFileStore(filePathProvider: previewProvider())
      )
    }
  }

  private func previewProvider() -> FilePathProvider {
    FilePathProvider(
      rootDirectory:
        FileManager.default.temporaryDirectory
        .appendingPathComponent("awairo-preview-\(UUID().uuidString)"))
  }

  private struct AlwaysEmptyRepo: PhotoRepository {
    func todayPhoto(now: Date) async throws -> Photo? { nil }
    func insert(_ photo: Photo) async throws {}
    func findAllOrderByTakenAtDesc() async throws -> [Photo] { [] }
    func findById(_ id: UUID) async throws -> Photo? { nil }
    func updateMemo(id: UUID, memo: String?) async throws {}
  }

  private struct AlwaysReturnRepo: PhotoRepository {
    let photo: Photo
    func todayPhoto(now: Date) async throws -> Photo? { photo }
    func insert(_ photo: Photo) async throws {}
    func findAllOrderByTakenAtDesc() async throws -> [Photo] { [photo] }
    func findById(_ id: UUID) async throws -> Photo? { photo.id == id ? photo : nil }
    func updateMemo(id: UUID, memo: String?) async throws {}
  }

  private struct AlwaysAuthorizedPermission: CameraPermission {
    func currentStatus() async -> CameraPermissionStatus { .authorized }
    func requestIfNeeded() async -> CameraPermissionStatus { .authorized }
  }
#endif
