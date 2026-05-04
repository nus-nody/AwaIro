import AwaIroDomain
import Foundation

public enum MemoState: Equatable, Sendable {
  case editing(memo: String)
  case saving
  case saved(Photo)
  case failed(message: String)
}

@Observable
@MainActor
public final class MemoViewModel {
  public private(set) var state: MemoState = .editing(memo: "")

  public let fileURL: URL
  public let takenAt: Date
  private let recordPhoto: RecordPhotoUseCase
  private let cleanup: @Sendable (URL) async -> Void

  public init(
    fileURL: URL,
    takenAt: Date,
    recordPhoto: RecordPhotoUseCase,
    cleanup: @escaping @Sendable (URL) async -> Void
  ) {
    self.fileURL = fileURL
    self.takenAt = takenAt
    self.recordPhoto = recordPhoto
    self.cleanup = cleanup
  }

  public func setMemo(_ memo: String) {
    if case .editing = state {
      state = .editing(memo: memo)
    }
  }

  public func save() async {
    guard case .editing(let memo) = state else { return }
    state = .saving
    let memoOrNil: String? = memo.isEmpty ? nil : memo
    do {
      let photo = try await recordPhoto.execute(
        fileURL: fileURL,
        takenAt: takenAt,
        memo: memoOrNil
      )
      state = .saved(photo)
    } catch {
      state = .failed(message: String(describing: error))
    }
  }

  public func cancel() async {
    await cleanup(fileURL)
  }
}
