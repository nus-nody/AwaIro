import AwaIroDomain
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

  private let usecase: GetTodayPhotoUseCase

  public init(usecase: GetTodayPhotoUseCase) {
    self.usecase = usecase
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
  }
}
