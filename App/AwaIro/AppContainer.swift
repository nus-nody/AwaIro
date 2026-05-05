import AVFoundation
import AwaIroData
import AwaIroDomain
import AwaIroPlatform
import AwaIroPresentation
import Foundation
import SwiftUI

@MainActor
final class AppContainer {
  let filePathProvider: FilePathProvider
  let photoRepository: any PhotoRepository
  let themeRepository: any ThemeRepository
  let getTodayPhotoUseCase: GetTodayPhotoUseCase
  let recordPhotoUseCase: RecordPhotoUseCase
  let developPhotoUseCase: DevelopPhotoUseCase
  let updateMemoUseCase: UpdateMemoUseCase
  let cameraPermission: any CameraPermission
  let camera: any CameraController
  let photoFileStore: PhotoFileStore
  let themeStore: ThemeStore

  init() throws {
    let provider = try FilePathProvider.defaultProduction()
    self.filePathProvider = provider

    let pool = try DatabaseFactory.makePool(at: provider.databaseURL)
    let repo = PhotoRepositoryImpl(writer: pool)
    self.photoRepository = repo

    let themeRepo = UserDefaultsThemeRepository()
    self.themeRepository = themeRepo

    self.getTodayPhotoUseCase = GetTodayPhotoUseCase(repository: repo)
    self.recordPhotoUseCase = RecordPhotoUseCase(repository: repo)
    self.developPhotoUseCase = DevelopPhotoUseCase(repository: repo)
    self.updateMemoUseCase = UpdateMemoUseCase(repository: repo)
    self.cameraPermission = AVFoundationCameraPermission()
    self.camera = AVFoundationCameraController()
    self.photoFileStore = PhotoFileStore(filePathProvider: provider)
    self.themeStore = ThemeStore(repository: themeRepo)
  }

  func makeHomeViewModel() -> HomeViewModel {
    let cameraRef = camera
    return HomeViewModel(
      usecase: getTodayPhotoUseCase,
      cameraPermission: cameraPermission,
      capturePhotoData: { try await cameraRef.capture() },
      photoFileStore: photoFileStore
    )
  }

  func makeMemoViewModel(fileURL: URL, takenAt: Date) -> MemoViewModel {
    let storeRef = photoFileStore
    return MemoViewModel(
      fileURL: fileURL,
      takenAt: takenAt,
      recordPhoto: recordPhotoUseCase,
      cleanup: { url in
        try? storeRef.delete(at: url)
      }
    )
  }

  func makeGalleryViewModel() -> GalleryViewModel {
    GalleryViewModel(usecase: developPhotoUseCase)
  }

  func makePhotoDetailViewModel(photo: Photo) -> PhotoDetailViewModel {
    PhotoDetailViewModel(photo: photo, updateMemo: updateMemoUseCase)
  }
}
