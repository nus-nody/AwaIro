#if canImport(UIKit)
  import AwaIroDomain
  import SnapshotTesting
  import SwiftUI
  import Testing
  import UIKit

  @testable import AwaIroPresentation

  @Suite("PaletteSheet snapshot")
  @MainActor
  struct PaletteSheetSnapshotTests {

    @Test("default selection snapshot is stable")
    func defaultSelectionSnapshot() {
      let view = PaletteSheet(
        selectedPalette: .nightSky, selectedMode: .system,
        onPickPalette: { _ in }, onPickMode: { _ in }
      ).skyTheme(.default)
      let host = UIHostingController(rootView: view)
      assertSnapshot(of: host, as: .image(on: .iPhoneX(.portrait)))
    }

    @Test("dusk + light selection snapshot is stable")
    func duskLightSelection() {
      let theme = SkyTheme(palette: .dusk, mode: .light, systemColorScheme: .light)
      let view = PaletteSheet(
        selectedPalette: .dusk, selectedMode: .light,
        onPickPalette: { _ in }, onPickMode: { _ in }
      ).skyTheme(theme)
      let host = UIHostingController(rootView: view)
      assertSnapshot(of: host, as: .image(on: .iPhoneX(.portrait)))
    }
  }
#endif
