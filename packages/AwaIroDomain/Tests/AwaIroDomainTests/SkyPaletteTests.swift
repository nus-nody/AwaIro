import Testing

@testable import AwaIroDomain

@Suite("SkyPalette + ThemeMode")
struct SkyPaletteTests {
  @Test("SkyPalette has all six expected cases")
  func sixPalettes() {
    let allCases = SkyPalette.allCases
    #expect(allCases.count == 6)
    #expect(allCases.contains(.nightSky))
    #expect(allCases.contains(.mist))
    #expect(allCases.contains(.dusk))
    #expect(allCases.contains(.komorebi))
    #expect(allCases.contains(.akatsuki))
    #expect(allCases.contains(.silverFog))
  }

  @Test("SkyPalette rawValue stable for persistence")
  func stableRawValue() {
    #expect(SkyPalette.nightSky.rawValue == "night_sky")
    #expect(SkyPalette.mist.rawValue == "mist")
    #expect(SkyPalette.dusk.rawValue == "dusk")
    #expect(SkyPalette.komorebi.rawValue == "komorebi")
    #expect(SkyPalette.akatsuki.rawValue == "akatsuki")
    #expect(SkyPalette.silverFog.rawValue == "silver_fog")
  }

  @Test("SkyPalette.from(rawValue:) returns nil for unknown")
  func fromUnknown() {
    #expect(SkyPalette(rawValue: "unknown") == nil)
  }

  @Test("ThemeMode has system/dark/light")
  func threeModes() {
    #expect(ThemeMode.allCases.count == 3)
    #expect(ThemeMode.system.rawValue == "system")
    #expect(ThemeMode.dark.rawValue == "dark")
    #expect(ThemeMode.light.rawValue == "light")
  }
}
