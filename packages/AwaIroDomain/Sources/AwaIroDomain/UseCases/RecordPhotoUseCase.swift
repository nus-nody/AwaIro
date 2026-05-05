import Foundation

public struct RecordPhotoUseCase: Sendable {
  private let repository: any PhotoRepository

  public init(repository: any PhotoRepository) {
    self.repository = repository
  }

  /// Inserts a new photo if no photo exists for today's calendar day.
  /// G1 guardrail: throws .alreadyRecordedToday if a photo already exists.
  /// Repository failures are wrapped in .repositoryFailure(message:).
  public func execute(fileURL: URL, takenAt: Date, memo: String?) async throws -> Photo {
    if try await repository.todayPhoto(now: takenAt) != nil {
      throw RecordPhotoError.alreadyRecordedToday
    }

    let photo = Photo(
      id: UUID(),
      takenAt: takenAt,
      developedAt: takenAt.addingTimeInterval(86400),
      fileURL: fileURL,
      memo: memo
    )

    do {
      try await repository.insert(photo)
    } catch let recordError as RecordPhotoError {
      throw recordError
    } catch {
      throw RecordPhotoError.repositoryFailure(message: String(describing: error))
    }

    return photo
  }
}
