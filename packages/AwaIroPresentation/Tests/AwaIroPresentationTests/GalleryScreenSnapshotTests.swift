#if canImport(UIKit)
  import AwaIroDomain
  import SnapshotTesting
  import SwiftUI
  import Testing
  import UIKit

  @testable import AwaIroPresentation

  @Suite("GalleryScreen snapshot — G3 guardrail")
  @MainActor
  struct GalleryScreenSnapshotTests {

    private let prohibitedWords: [String] = [
      "いいね", "Like", "Likes",
      "フォロワー", "Follower", "Followers",
      "閲覧", "Views", "View count",
      "シェア数", "Shares",
    ]

    @Test("empty state snapshot is stable")
    func emptySnapshot() {
      let view = GalleryContentView(state: .empty).skyTheme(.default)
      let host = UIHostingController(rootView: view)
      assertSnapshot(of: host, as: .image(on: .iPhoneX(.portrait)))
    }

    @Test("loaded state snapshot — all undeveloped is stable")
    func allUndevelopedSnapshot() {
      let now = Date(timeIntervalSince1970: 1_730_000_000)
      let photos: [Photo] = (0..<3).map { i in
        let taken = now.addingTimeInterval(TimeInterval(-i * 3600))
        return Photo(
          id: UUID(uuidString: "00000000-0000-0000-0000-00000000000\(i)")!,
          takenAt: taken,
          developedAt: taken.addingTimeInterval(86400),
          fileURL: URL(fileURLWithPath: "/tmp/x\(i).jpg"),
          memo: nil
        )
      }
      let view = GalleryContentView(state: .loaded(photos: photos, asOf: now))
        .skyTheme(.default)
      let host = UIHostingController(rootView: view)
      assertSnapshot(of: host, as: .image(on: .iPhoneX(.portrait)))
    }

    @Test("GalleryContentView contains no numeric-metric strings (G3)")
    func noNumericMetrics() {
      let now = Date(timeIntervalSince1970: 1_730_000_000)
      let photos: [Photo] = [
        Photo(
          id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
          takenAt: now.addingTimeInterval(-12 * 3600),
          developedAt: now.addingTimeInterval(12 * 3600),
          fileURL: URL(fileURLWithPath: "/tmp/x.jpg"), memo: nil
        ),
        Photo(
          id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
          takenAt: now.addingTimeInterval(-30 * 3600),
          developedAt: now.addingTimeInterval(-6 * 3600),
          fileURL: URL(fileURLWithPath: "/tmp/y.jpg"), memo: nil
        ),
      ]
      let view = GalleryContentView(state: .loaded(photos: photos, asOf: now))
        .skyTheme(.default)
      let host = UIHostingController(rootView: view)
      host.loadViewIfNeeded()
      host.view.frame = UIScreen.main.bounds
      host.view.layoutIfNeeded()
      let allText = collectText(in: host.view)
      for word in prohibitedWords {
        #expect(
          !allText.contains(word),
          "G3 guardrail violation: '\(word)' appeared.\nFull text: \(allText)")
      }
    }

    private func collectText(in view: UIView) -> String {
      var parts: [String] = []
      if let label = view as? UILabel, let t = label.text { parts.append(t) }
      if let textView = view as? UITextView { parts.append(textView.text) }
      for sub in view.subviews { parts.append(collectText(in: sub)) }
      return parts.joined(separator: "|")
    }
  }
#endif
