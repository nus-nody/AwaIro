import SwiftUI

/// Reusable bottom bar with leading + trailing icon buttons.
/// Used by HomeScreen (gallery + menu) and GalleryScreen (home + menu).
public struct BottomActionBar: View {
  public let leadingSystemName: String
  public let leadingLabel: String
  public let trailingSystemName: String
  public let trailingLabel: String
  public let onTapLeading: () -> Void
  public let onTapTrailing: () -> Void

  @Environment(\.skyTheme) private var theme

  public init(
    leadingSystemName: String,
    leadingLabel: String,
    trailingSystemName: String,
    trailingLabel: String,
    onTapLeading: @escaping () -> Void,
    onTapTrailing: @escaping () -> Void
  ) {
    self.leadingSystemName = leadingSystemName
    self.leadingLabel = leadingLabel
    self.trailingSystemName = trailingSystemName
    self.trailingLabel = trailingLabel
    self.onTapLeading = onTapLeading
    self.onTapTrailing = onTapTrailing
  }

  public var body: some View {
    HStack {
      Button(action: onTapLeading) {
        Image(systemName: leadingSystemName)
          .font(.title2)
      }
      .accessibilityLabel(leadingLabel)
      Spacer()
      Button(action: onTapTrailing) {
        Image(systemName: trailingSystemName)
          .font(.title2)
      }
      .accessibilityLabel(trailingLabel)
    }
    .foregroundStyle(theme.textPrimary)
    .padding(.horizontal, 24)
    .padding(.bottom, 16)
  }
}
