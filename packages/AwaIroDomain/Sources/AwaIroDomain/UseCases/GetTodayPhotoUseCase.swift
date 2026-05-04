import Foundation

public struct GetTodayPhotoUseCase: Sendable {
  private let repository: any PhotoRepository

  public init(repository: any PhotoRepository) {
    self.repository = repository
  }

  public func execute(now: Date) async throws -> Photo? {
    try await repository.todayPhoto(now: now)
  }
}
