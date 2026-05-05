import AwaIroDomain
import Foundation

public enum GalleryState: Equatable, Sendable {
  case loading
  case empty
  case loaded(photos: [Photo], asOf: Date)
  case failed(message: String)
}

@Observable
@MainActor
public final class GalleryViewModel {
  public private(set) var state: GalleryState = .loading
  private let usecase: DevelopPhotoUseCase

  public init(usecase: DevelopPhotoUseCase) {
    self.usecase = usecase
  }

  public func load(now: Date) async {
    state = .loading
    do {
      let photos = try await usecase.execute()
      if photos.isEmpty {
        state = .empty
      } else {
        state = .loaded(photos: photos, asOf: now)
      }
    } catch {
      state = .failed(message: String(describing: error))
    }
  }

  /// Updates the `asOf` reference time so `isDeveloped` re-evaluates without re-fetching.
  /// Called by a periodic tick (e.g. every 60s) while the gallery is visible.
  public func tickNow(_ newNow: Date) {
    if case .loaded(let photos, _) = state {
      state = .loaded(photos: photos, asOf: newNow)
    }
  }
}
