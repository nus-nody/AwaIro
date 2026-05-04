import AwaIroDomain
import AwaIroPlatform
import Foundation

public enum HomeState: Equatable, Sendable {
  case loading
  case unrecorded
  case recorded(Photo)
  case failed(String)
}

@Observable
@MainActor
public final class HomeViewModel {
  public private(set) var state: HomeState = .loading
  public private(set) var permission: CameraPermissionStatus = .notDetermined

  private let usecase: GetTodayPhotoUseCase
  private let cameraPermission: any CameraPermission
  private let capturePhotoData: @Sendable () async throws -> Data
  private let photoFileStore: PhotoFileStore

  public init(
    usecase: GetTodayPhotoUseCase,
    cameraPermission: any CameraPermission,
    capturePhotoData: @escaping @Sendable () async throws -> Data,
    photoFileStore: PhotoFileStore
  ) {
    self.usecase = usecase
    self.cameraPermission = cameraPermission
    self.capturePhotoData = capturePhotoData
    self.photoFileStore = photoFileStore
  }

  public func load(now: Date) async {
    state = .loading
    do {
      if let photo = try await usecase.execute(now: now) {
        state = .recorded(photo)
      } else {
        state = .unrecorded
      }
    } catch {
      state = .failed(String(describing: error))
    }
    permission = await cameraPermission.currentStatus()
  }

  public func requestCameraIfNeeded() async {
    permission = await cameraPermission.requestIfNeeded()
  }

  /// Captures a photo via the injected closure, writes the JPEG to disk,
  /// and returns the file URL. Returns nil on failure.
  public func capturePhoto() async -> URL? {
    do {
      let data = try await capturePhotoData()
      let id = UUID()
      let url = try photoFileStore.write(data: data, photoId: id)
      return url
    } catch {
      state = .failed(String(describing: error))
      return nil
    }
  }
}
