import Foundation

/// Six selectable color palettes for the gallery sky.
/// Stored via `rawValue`, so do not change values without a migration.
public enum SkyPalette: String, CaseIterable, Hashable, Codable, Sendable {
  case nightSky = "night_sky"
  case mist = "mist"
  case dusk = "dusk"
  case komorebi = "komorebi"
  case akatsuki = "akatsuki"
  case silverFog = "silver_fog"

  public var displayName: String {
    switch self {
    case .nightSky: "夜空"
    case .mist: "霧海"
    case .dusk: "夕暮れ"
    case .komorebi: "木漏れ日"
    case .akatsuki: "暁"
    case .silverFog: "銀霧"
    }
  }
}
