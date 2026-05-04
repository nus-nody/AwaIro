import Foundation
import AwaIroDomain
import AwaIroData
import AwaIroPlatform
import AwaIroPresentation

@MainActor
final class AppContainer {
    let filePathProvider: FilePathProvider
    let photoRepository: any PhotoRepository
    let getTodayPhotoUseCase: GetTodayPhotoUseCase

    init() throws {
        let provider = try FilePathProvider.defaultProduction()
        self.filePathProvider = provider

        let pool = try DatabaseFactory.makePool(at: provider.databaseURL)
        let repo = PhotoRepositoryImpl(writer: pool)
        self.photoRepository = repo

        self.getTodayPhotoUseCase = GetTodayPhotoUseCase(repository: repo)
    }

    func makeHomeViewModel() -> HomeViewModel {
        HomeViewModel(usecase: getTodayPhotoUseCase)
    }
}
