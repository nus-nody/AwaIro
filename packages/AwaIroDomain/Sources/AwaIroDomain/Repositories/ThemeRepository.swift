import Foundation

/// Persists the user's theme preferences (palette + mode).
/// Thread-safe implementations are required to be `Sendable`.
public protocol ThemeRepository: Sendable {
  func getPalette() async -> SkyPalette
  func setPalette(_ palette: SkyPalette) async
  func getMode() async -> ThemeMode
  func setMode(_ mode: ThemeMode) async
}
