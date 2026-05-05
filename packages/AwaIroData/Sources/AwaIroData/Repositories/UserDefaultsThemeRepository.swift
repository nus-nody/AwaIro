import AwaIroDomain
import Foundation

public final class UserDefaultsThemeRepository: ThemeRepository, @unchecked Sendable {
  private static let paletteKey = "awairo.skyPalette"
  private static let modeKey = "awairo.themeMode"

  private let defaults: UserDefaults

  public init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
  }

  public func getPalette() async -> SkyPalette {
    if let raw = defaults.string(forKey: Self.paletteKey),
      let palette = SkyPalette(rawValue: raw)
    {
      return palette
    }
    return .nightSky
  }

  public func setPalette(_ palette: SkyPalette) async {
    defaults.set(palette.rawValue, forKey: Self.paletteKey)
  }

  public func getMode() async -> ThemeMode {
    if let raw = defaults.string(forKey: Self.modeKey),
      let mode = ThemeMode(rawValue: raw)
    {
      return mode
    }
    return .system
  }

  public func setMode(_ mode: ThemeMode) async {
    defaults.set(mode.rawValue, forKey: Self.modeKey)
  }
}
