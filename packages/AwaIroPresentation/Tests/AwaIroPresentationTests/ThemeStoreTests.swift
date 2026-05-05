import AwaIroDomain
import Foundation
import Testing

@testable import AwaIroPresentation

@Suite("ThemeStore @Observable")
@MainActor
struct ThemeStoreTests {

  @Test("starts with default values before load()")
  func initialDefaults() {
    let repo = FakeThemeRepo()
    let store = ThemeStore(repository: repo)
    #expect(store.palette == .nightSky)
    #expect(store.mode == .system)
  }

  @Test("load() reflects repository state")
  func loadFromRepo() async {
    let repo = FakeThemeRepo(palette: .dusk, mode: .dark)
    let store = ThemeStore(repository: repo)
    await store.load()
    #expect(store.palette == .dusk)
    #expect(store.mode == .dark)
  }

  @Test("setPalette writes to repository and updates state")
  func setPaletteWrites() async {
    let repo = FakeThemeRepo()
    let store = ThemeStore(repository: repo)
    await store.setPalette(.komorebi)
    #expect(store.palette == .komorebi)
    #expect(await repo.getPalette() == .komorebi)
  }

  @Test("setMode writes to repository and updates state")
  func setModeWrites() async {
    let repo = FakeThemeRepo()
    let store = ThemeStore(repository: repo)
    await store.setMode(.light)
    #expect(store.mode == .light)
    #expect(await repo.getMode() == .light)
  }
}

private final class FakeThemeRepo: ThemeRepository, @unchecked Sendable {
  private var palette: SkyPalette
  private var mode: ThemeMode
  init(palette: SkyPalette = .nightSky, mode: ThemeMode = .system) {
    self.palette = palette
    self.mode = mode
  }
  func getPalette() async -> SkyPalette { palette }
  func setPalette(_ p: SkyPalette) async { palette = p }
  func getMode() async -> ThemeMode { mode }
  func setMode(_ m: ThemeMode) async { mode = m }
}
