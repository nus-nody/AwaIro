#if canImport(UIKit)
  import Testing
  import UIKit
  import SwiftUI
  import SnapshotTesting
  import AwaIroDomain
  @testable import AwaIroPresentation

  /// Snapshots target HomeContentView — the pure state-driven inner view that HomeScreen composes.
  /// Snapshotting HomeScreen directly is not viable because its .task modifier resets state to
  /// .loading before the synchronous snapshot renderer captures the frame.
  /// HomeContentView has no async side-effects and renders deterministically for a given HomeState.
  @Suite("HomeScreen snapshot — G3 guardrail")
  @MainActor
  struct HomeScreenSnapshotTests {

    /// G3 guardrail: View ツリーに「いいね数」「フォロワー」「閲覧」等の他者評価指標が現れないこと。
    /// この test は禁止語が UI 文字列として描画されていないことを assert する。
    private let prohibitedWords: [String] = [
      "いいね", "Like", "Likes",
      "フォロワー", "Follower", "Followers",
      "閲覧", "Views", "View count",
      "シェア数", "Shares",
    ]

    @Test("unrecorded snapshot is stable")
    func unrecordedSnapshot() {
      let host = UIHostingController(rootView: HomeContentView(state: .unrecorded))
      assertSnapshot(of: host, as: .image(on: .iPhoneX(.portrait)))
    }

    @Test("recorded snapshot is stable")
    func recordedSnapshot() {
      let photo = Photo(
        id: UUID(),
        takenAt: Date(),
        fileURL: URL(fileURLWithPath: "/tmp/preview.jpg"),
        memo: "preview"
      )
      let host = UIHostingController(rootView: HomeContentView(state: .recorded(photo)))
      assertSnapshot(of: host, as: .image(on: .iPhoneX(.portrait)))
    }

    @Test("HomeScreen contains no numeric-metric strings (G3)")
    func noNumericMetrics() {
      let photo = Photo(
        id: UUID(),
        takenAt: Date(),
        fileURL: URL(fileURLWithPath: "/tmp/preview.jpg"),
        memo: "preview"
      )
      let host = UIHostingController(rootView: HomeContentView(state: .recorded(photo)))
      host.loadViewIfNeeded()
      host.view.frame = UIScreen.main.bounds
      host.view.layoutIfNeeded()

      let allText = collectText(in: host.view)
      for word in prohibitedWords {
        #expect(
          !allText.contains(word),
          "G3 guardrail violation: '\(word)' appeared in HomeScreen view tree.\nFull text: \(allText)"
        )
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
