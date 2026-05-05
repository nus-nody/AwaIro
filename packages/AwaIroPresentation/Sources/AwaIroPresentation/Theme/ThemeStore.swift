import AwaIroDomain
import Foundation

@Observable
@MainActor
public final class ThemeStore {
  public private(set) var palette: SkyPalette = .nightSky
  public private(set) var mode: ThemeMode = .system

  private let repository: any ThemeRepository

  public init(repository: any ThemeRepository) {
    self.repository = repository
  }

  public func load() async {
    palette = await repository.getPalette()
    mode = await repository.getMode()
  }

  public func setPalette(_ p: SkyPalette) async {
    palette = p
    await repository.setPalette(p)
  }

  public func setMode(_ m: ThemeMode) async {
    mode = m
    await repository.setMode(m)
  }
}
