#if canImport(UIKit)
  import Testing
  import UIKit
  import SwiftUI
  import SnapshotTesting
  import AwaIroDomain
  import AwaIroPlatform
  @testable import AwaIroPresentation

  @Suite("HomeScreen snapshot — G3 guardrail")
  @MainActor
  struct HomeScreenSnapshotTests {

    private let prohibitedWords: [String] = [
      "いいね", "Like", "Likes",
      "フォロワー", "Follower", "Followers",
      "閲覧", "Views", "View count",
      "シェア数", "Shares",
    ]

    @Test("unrecorded + authorized snapshot is stable")
    func unrecordedAuthorizedSnapshot() {
      let view = HomeContentView(
        state: .unrecorded,
        permission: .authorized,
        bubble: { Circle().fill(.white.opacity(0.85)).frame(width: 280, height: 280) },
        onRequestPermission: {}
      )
      let host = UIHostingController(rootView: view)
      assertSnapshot(of: host, as: .image(on: .iPhoneX(.portrait)))
    }

    @Test("unrecorded + notDetermined snapshot is stable")
    func unrecordedNotDeterminedSnapshot() {
      let view = HomeContentView(
        state: .unrecorded,
        permission: .notDetermined,
        bubble: { EmptyView() },
        onRequestPermission: {}
      )
      let host = UIHostingController(rootView: view)
      assertSnapshot(of: host, as: .image(on: .iPhoneX(.portrait)))
    }

    @Test("unrecorded + denied snapshot is stable")
    func unrecordedDeniedSnapshot() {
      let view = HomeContentView(
        state: .unrecorded,
        permission: .denied,
        bubble: { EmptyView() },
        onRequestPermission: {}
      )
      let host = UIHostingController(rootView: view)
      assertSnapshot(of: host, as: .image(on: .iPhoneX(.portrait)))
    }

    @Test("recorded snapshot is stable")
    func recordedSnapshot() {
      let view = HomeContentView(
        state: .recorded(
          Photo(
            id: UUID(),
            takenAt: Date(),
            fileURL: URL(fileURLWithPath: "/tmp/preview.jpg"),
            memo: "preview"
          )),
        permission: .authorized,
        bubble: { EmptyView() },
        onRequestPermission: {}
      )
      let host = UIHostingController(rootView: view)
      assertSnapshot(of: host, as: .image(on: .iPhoneX(.portrait)))
    }

    @Test("HomeContentView contains no numeric-metric strings (G3)")
    func noNumericMetrics() {
      let view = HomeContentView(
        state: .recorded(
          Photo(
            id: UUID(),
            takenAt: Date(),
            fileURL: URL(fileURLWithPath: "/tmp/preview.jpg"),
            memo: "preview"
          )),
        permission: .authorized,
        bubble: { EmptyView() },
        onRequestPermission: {}
      )
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
