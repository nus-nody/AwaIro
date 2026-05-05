import AwaIroDomain
import Foundation
import Testing

@testable import AwaIroData

@Suite("UserDefaultsThemeRepository")
struct UserDefaultsThemeRepositoryTests {

  private func makeDefaults() -> UserDefaults {
    let suiteName = "test-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defaults.removePersistentDomain(forName: suiteName)
    return defaults
  }

  @Test("default palette is nightSky when nothing stored")
  func defaultPalette() async {
    let repo = UserDefaultsThemeRepository(defaults: makeDefaults())
    let palette = await repo.getPalette()
    #expect(palette == .nightSky)
  }

  @Test("default mode is system when nothing stored")
  func defaultMode() async {
    let repo = UserDefaultsThemeRepository(defaults: makeDefaults())
    let mode = await repo.getMode()
    #expect(mode == .system)
  }

  @Test("setPalette persists and is readable")
  func roundTripPalette() async {
    let repo = UserDefaultsThemeRepository(defaults: makeDefaults())
    await repo.setPalette(.dusk)
    let result = await repo.getPalette()
    #expect(result == .dusk)
  }

  @Test("setMode persists and is readable")
  func roundTripMode() async {
    let repo = UserDefaultsThemeRepository(defaults: makeDefaults())
    await repo.setMode(.dark)
    let result = await repo.getMode()
    #expect(result == .dark)
  }

  @Test("unknown stored palette falls back to default")
  func unknownPaletteFallback() async {
    let defaults = makeDefaults()
    defaults.set("garbage", forKey: "awairo.skyPalette")
    let repo = UserDefaultsThemeRepository(defaults: defaults)
    let palette = await repo.getPalette()
    #expect(palette == .nightSky)
  }
}
