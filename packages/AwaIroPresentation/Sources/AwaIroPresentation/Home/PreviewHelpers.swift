#if DEBUG
  import Foundation
  import AwaIroDomain

  @MainActor
  public enum PreviewHelpers {
    public static func unrecordedVM() -> HomeViewModel {
      HomeViewModel(usecase: GetTodayPhotoUseCase(repository: AlwaysEmptyRepo()))
    }

    public static func recordedVM() -> HomeViewModel {
      let photo = Photo(
        id: UUID(),
        takenAt: Date(),
        fileURL: URL(fileURLWithPath: "/tmp/preview.jpg"),
        memo: "preview"
      )
      return HomeViewModel(
        usecase: GetTodayPhotoUseCase(repository: AlwaysReturnRepo(photo: photo)))
    }
  }

  private struct AlwaysEmptyRepo: PhotoRepository {
    func todayPhoto(now: Date) async throws -> Photo? { nil }
    func insert(_ photo: Photo) async throws {}
  }

  private struct AlwaysReturnRepo: PhotoRepository {
    let photo: Photo
    func todayPhoto(now: Date) async throws -> Photo? { photo }
    func insert(_ photo: Photo) async throws {}
  }
#endif
