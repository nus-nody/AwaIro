import Foundation

public struct DevelopPhotoUseCase: Sendable {
  private let repository: any PhotoRepository

  public init(repository: any PhotoRepository) {
    self.repository = repository
  }

  /// Returns all photos ordered by takenAt descending (newest first).
  /// Callers determine `isDeveloped` per photo using `Photo.isDeveloped(now:)`.
  public func execute() async throws -> [Photo] {
    try await repository.findAllOrderByTakenAtDesc()
  }
}
