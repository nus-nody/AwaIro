import AwaIroDomain
import Foundation

public enum PhotoDetailState: Equatable, Sendable {
  case viewing(Photo)
  case editing(Photo, draft: String)
  case saving(Photo)
  case failed(Photo, message: String)
}

@Observable
@MainActor
public final class PhotoDetailViewModel {
  public private(set) var state: PhotoDetailState
  private let updateMemo: UpdateMemoUseCase

  public init(photo: Photo, updateMemo: UpdateMemoUseCase) {
    self.state = .viewing(photo)
    self.updateMemo = updateMemo
  }

  public func startEditing() {
    if case .viewing(let p) = state {
      state = .editing(p, draft: p.memo ?? "")
    }
  }

  public func setDraft(_ s: String) {
    if case .editing(let p, _) = state {
      state = .editing(p, draft: s)
    }
  }

  public func cancelEditing() {
    if case .editing(let p, _) = state {
      state = .viewing(p)
    }
  }

  public func save() async {
    guard case .editing(let p, let draft) = state else { return }
    let memoOrNil: String? = draft.isEmpty ? nil : draft
    state = .saving(p)
    do {
      try await updateMemo.execute(id: p.id, memo: memoOrNil)
      let updated = Photo(
        id: p.id, takenAt: p.takenAt, developedAt: p.developedAt,
        fileURL: p.fileURL, memo: memoOrNil)
      state = .viewing(updated)
    } catch {
      state = .failed(p, message: String(describing: error))
    }
  }
}
