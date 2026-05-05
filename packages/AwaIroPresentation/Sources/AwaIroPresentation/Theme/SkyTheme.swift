import AwaIroDomain
import SwiftUI

public struct SkyTheme: Equatable, Sendable {
  public let palette: SkyPalette
  public let mode: ThemeMode
  public let isDark: Bool
  public let backgroundTop: Color
  public let backgroundBottom: Color
  public let textPrimary: Color
  public let textSecondary: Color

  public init(palette: SkyPalette, mode: ThemeMode, systemColorScheme: ColorScheme) {
    self.palette = palette
    self.mode = mode

    let resolvedDark: Bool
    switch mode {
    case .system: resolvedDark = systemColorScheme == .dark
    case .dark: resolvedDark = true
    case .light: resolvedDark = false
    }
    self.isDark = resolvedDark

    let colors = Self.resolve(palette: palette, isDark: resolvedDark)
    self.backgroundTop = colors.top
    self.backgroundBottom = colors.bottom
    self.textPrimary = resolvedDark ? .white : .black
    self.textSecondary = resolvedDark ? Color.white.opacity(0.6) : Color.black.opacity(0.55)
  }

  /// Default theme used when env not provided (e.g. previews / snapshots).
  public static let `default` = SkyTheme(
    palette: .nightSky, mode: .dark, systemColorScheme: .dark)

  private static func resolve(palette: SkyPalette, isDark: Bool) -> (top: Color, bottom: Color) {
    switch (palette, isDark) {
    case (.nightSky, true):
      return (Color(red: 0.06, green: 0.05, blue: 0.18), Color(red: 0.10, green: 0.10, blue: 0.30))
    case (.nightSky, false):
      return (Color(red: 0.78, green: 0.74, blue: 0.92), Color(red: 0.92, green: 0.90, blue: 0.98))
    case (.mist, true):
      return (Color(red: 0.05, green: 0.10, blue: 0.18), Color(red: 0.08, green: 0.16, blue: 0.26))
    case (.mist, false):
      return (Color(red: 0.78, green: 0.84, blue: 0.92), Color(red: 0.90, green: 0.94, blue: 0.98))
    case (.dusk, true):
      return (Color(red: 0.18, green: 0.06, blue: 0.06), Color(red: 0.30, green: 0.10, blue: 0.10))
    case (.dusk, false):
      return (Color(red: 1.00, green: 0.78, blue: 0.74), Color(red: 1.00, green: 0.88, blue: 0.82))
    case (.komorebi, true):
      return (Color(red: 0.05, green: 0.18, blue: 0.06), Color(red: 0.08, green: 0.26, blue: 0.10))
    case (.komorebi, false):
      return (Color(red: 0.78, green: 0.92, blue: 0.74), Color(red: 0.90, green: 0.98, blue: 0.84))
    case (.akatsuki, true):
      return (Color(red: 0.18, green: 0.05, blue: 0.18), Color(red: 0.30, green: 0.08, blue: 0.30))
    case (.akatsuki, false):
      return (Color(red: 1.00, green: 0.84, blue: 0.92), Color(red: 1.00, green: 0.92, blue: 0.96))
    case (.silverFog, true):
      return (Color(red: 0.10, green: 0.10, blue: 0.18), Color(red: 0.14, green: 0.14, blue: 0.22))
    case (.silverFog, false):
      return (Color(red: 0.85, green: 0.85, blue: 0.88), Color(red: 0.94, green: 0.94, blue: 0.96))
    }
  }
}

private struct SkyThemeKey: EnvironmentKey {
  static let defaultValue: SkyTheme = .default
}

extension EnvironmentValues {
  public var skyTheme: SkyTheme {
    get { self[SkyThemeKey.self] }
    set { self[SkyThemeKey.self] = newValue }
  }
}

extension View {
  public func skyTheme(_ theme: SkyTheme) -> some View {
    self.environment(\.skyTheme, theme)
  }
}
