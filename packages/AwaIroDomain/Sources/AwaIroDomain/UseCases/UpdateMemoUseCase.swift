import Foundation

public struct UpdateMemoUseCase: Sendable {
  private let repository: any PhotoRepository

  public init(repository: any PhotoRepository) {
    self.repository = repository
  }

  public func execute(id: UUID, memo: String?) async throws {
    try await repository.updateMemo(id: id, memo: memo)
  }
}
