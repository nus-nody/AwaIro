#if canImport(UIKit)
  import AwaIroDomain
  import SnapshotTesting
  import SwiftUI
  import Testing
  import UIKit

  @testable import AwaIroPresentation

  @Suite("PhotoDetailScreen snapshot — G3 guardrail")
  @MainActor
  struct PhotoDetailScreenSnapshotTests {

    private let prohibitedWords: [String] = [
      "いいね", "Like", "Likes",
      "フォロワー", "Follower", "Followers",
      "閲覧", "Views", "View count",
      "シェア数", "Shares",
    ]

    private func makePhoto(memo: String?) -> Photo {
      let now = Date(timeIntervalSince1970: 1_730_000_000)
      return Photo(
        id: UUID(uuidString: "AAAAAAAA-1111-2222-3333-444444444444")!,
        takenAt: now, developedAt: now.addingTimeInterval(-3600),
        fileURL: URL(fileURLWithPath: "/tmp/x.jpg"), memo: memo)
    }

    @Test("viewing with memo snapshot is stable")
    func viewingWithMemo() {
      let view = PhotoDetailContentView(state: .viewing(makePhoto(memo: "朝の散歩")))
        .skyTheme(.default)
      let host = UIHostingController(rootView: view)
      assertSnapshot(of: host, as: .image(on: .iPhoneX(.portrait)))
    }

    @Test("viewing with no memo snapshot is stable")
    func viewingNoMemo() {
      let view = PhotoDetailContentView(state: .viewing(makePhoto(memo: nil)))
        .skyTheme(.default)
      let host = UIHostingController(rootView: view)
      assertSnapshot(of: host, as: .image(on: .iPhoneX(.portrait)))
    }

    @Test("editing snapshot is stable")
    func editingSnapshot() {
      let view = PhotoDetailContentView(
        state: .editing(makePhoto(memo: "古いメモ"), draft: "新しいメモ")
      ).skyTheme(.default)
      let host = UIHostingController(rootView: view)
      assertSnapshot(of: host, as: .image(on: .iPhoneX(.portrait)))
    }

    @Test("PhotoDetailContentView contains no numeric-metric strings (G3)")
    func noNumericMetrics() {
      let view = PhotoDetailContentView(state: .viewing(makePhoto(memo: "朝")))
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
