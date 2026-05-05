import AwaIroDomain
import SwiftUI

/// A single bubble in the gallery. Renders developed (with photo) or
/// undeveloped (translucent + remaining-time copy) variant.
public struct BubbleGalleryItem: View {
  public let photo: Photo
  public let now: Date
  public let size: CGFloat

  @Environment(\.skyTheme) private var theme
  @State private var floatY: CGFloat = 0

  public init(photo: Photo, now: Date, size: CGFloat = 145) {
    self.photo = photo
    self.now = now
    self.size = size
  }

  public var body: some View {
    ZStack {
      Circle()
        .fill(
          RadialGradient(
            colors: [
              Color.white.opacity(0.30),
              Color.white.opacity(0.10),
              Color.white.opacity(0.00),
            ],
            center: .topLeading,
            startRadius: 0, endRadius: size
          )
        )
        .overlay(Circle().stroke(Color.white.opacity(0.35), lineWidth: 1))

      if photo.isDeveloped(now: now) {
        AsyncImage(url: photo.fileURL) { image in
          image.resizable().scaledToFill()
        } placeholder: {
          Color.white.opacity(0.05)
        }
        .frame(width: size * 0.78, height: size * 0.78)
        .clipShape(Circle())
        .accessibilityLabel("撮影した写真")
      } else {
        Text(remainingCopy)
          .font(.caption)
          .foregroundStyle(theme.textSecondary)
          .accessibilityLabel("現像までの残り時間")
      }
    }
    .frame(width: size, height: size)
    .offset(y: floatY)
    .onAppear { startFloat() }
  }

  private func startFloat() {
    // Skip animation under XCTest / Swift Testing harness so snapshot frames stay deterministic.
    if NSClassFromString("XCTestCase") != nil { return }
    withAnimation(
      .easeInOut(duration: Double.random(in: 4...8)).repeatForever(autoreverses: true)
    ) {
      floatY = -8
    }
  }

  private var remainingCopy: String {
    let secs = max(0, photo.remainingUntilDeveloped(now: now))
    let hours = Int(secs / 3600)
    return hours <= 0 ? "もうすぐ" : "あと\(hours)時間"
  }
}

#if DEBUG
  #Preview("undeveloped — 12h left") {
    let now = Date(timeIntervalSince1970: 1_730_000_000)
    BubbleGalleryItem(
      photo: Photo(
        id: UUID(), takenAt: now.addingTimeInterval(-12 * 3600),
        developedAt: now.addingTimeInterval(12 * 3600),
        fileURL: URL(fileURLWithPath: "/tmp/x.jpg"), memo: nil),
      now: now, size: 180
    )
    .padding()
    .background(.black)
  }

  #Preview("developed") {
    let now = Date(timeIntervalSince1970: 1_730_000_000)
    BubbleGalleryItem(
      photo: Photo(
        id: UUID(), takenAt: now.addingTimeInterval(-25 * 3600),
        developedAt: now.addingTimeInterval(-1 * 3600),
        fileURL: URL(fileURLWithPath: "/tmp/x.jpg"), memo: nil),
      now: now, size: 180
    )
    .padding()
    .background(.black)
  }
#endif
