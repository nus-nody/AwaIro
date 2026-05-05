import AwaIroDomain
import SwiftUI

public struct PaletteSheet: View {
  public let selectedPalette: SkyPalette
  public let selectedMode: ThemeMode
  public let onPickPalette: (SkyPalette) -> Void
  public let onPickMode: (ThemeMode) -> Void

  @Environment(\.skyTheme) private var theme

  public init(
    selectedPalette: SkyPalette,
    selectedMode: ThemeMode,
    onPickPalette: @escaping (SkyPalette) -> Void,
    onPickMode: @escaping (ThemeMode) -> Void
  ) {
    self.selectedPalette = selectedPalette
    self.selectedMode = selectedMode
    self.onPickPalette = onPickPalette
    self.onPickMode = onPickMode
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: 24) {
      Text("空の色")
        .font(.headline)
        .foregroundStyle(theme.textPrimary)

      LazyVGrid(
        columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 3), spacing: 16
      ) {
        ForEach(SkyPalette.allCases, id: \.self) { palette in
          paletteSwatch(palette)
        }
      }

      Divider().background(theme.textSecondary)

      Text("テーマ")
        .font(.headline)
        .foregroundStyle(theme.textPrimary)

      HStack(spacing: 12) {
        ForEach(ThemeMode.allCases, id: \.self) { mode in
          modeButton(mode)
        }
      }
    }
    .padding()
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(
      LinearGradient(
        colors: [theme.backgroundTop, theme.backgroundBottom],
        startPoint: .top, endPoint: .bottom
      )
    )
  }

  @ViewBuilder
  private func paletteSwatch(_ palette: SkyPalette) -> some View {
    Button {
      onPickPalette(palette)
    } label: {
      VStack(spacing: 4) {
        let preview = SkyTheme(
          palette: palette, mode: theme.mode,
          systemColorScheme: theme.isDark ? .dark : .light)
        Circle()
          .fill(
            LinearGradient(
              colors: [preview.backgroundTop, preview.backgroundBottom],
              startPoint: .top, endPoint: .bottom
            )
          )
          .frame(width: 56, height: 56)
          .overlay(
            Circle()
              .stroke(palette == selectedPalette ? theme.textPrimary : .clear, lineWidth: 2)
          )
        Text(palette.displayName)
          .font(.caption)
          .foregroundStyle(theme.textPrimary)
      }
    }
    .accessibilityLabel(palette.displayName)
    .accessibilityAddTraits(palette == selectedPalette ? [.isSelected, .isButton] : .isButton)
  }

  @ViewBuilder
  private func modeButton(_ mode: ThemeMode) -> some View {
    let label: String = {
      switch mode {
      case .system: "システム"
      case .dark: "暗い"
      case .light: "明るい"
      }
    }()
    Button(label) { onPickMode(mode) }
      .buttonStyle(.bordered)
      .tint(theme.textPrimary)
      .opacity(mode == selectedMode ? 1.0 : 0.5)
      .accessibilityAddTraits(mode == selectedMode ? .isSelected : [])
  }
}

#if DEBUG
  #Preview {
    PaletteSheet(
      selectedPalette: .nightSky, selectedMode: .system,
      onPickPalette: { _ in }, onPickMode: { _ in }
    )
  }
#endif
