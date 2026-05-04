#if canImport(UIKit)
  import Testing
  import UIKit
  import SwiftUI
  import SnapshotTesting
  import AwaIroDomain
  @testable import AwaIroPresentation

  @Suite("MemoScreen snapshot — G3 guardrail")
  @MainActor
  struct MemoScreenSnapshotTests {

    private let prohibitedWords: [String] = [
      "いいね", "Like", "Likes",
      "フォロワー", "Follower", "Followers",
      "閲覧", "Views", "View count",
      "シェア数", "Shares",
    ]

    private func makeVM(memo: String = "") -> MemoViewModel {
      let vm = MemoViewModel(
        fileURL: URL(fileURLWithPath: "/tmp/missing-on-purpose.jpg"),
        takenAt: Date(),
        recordPhoto: RecordPhotoUseCase(repository: NoOpRepo()),
        cleanup: { _ in }
      )
      vm.setMemo(memo)
      return vm
    }

    @Test("editing snapshot is stable")
    func editingSnapshot() {
      let host = UIHostingController(
        rootView: MemoScreen(viewModel: makeVM(memo: "morning"), onFinished: {}))
      assertSnapshot(of: host, as: .image(on: .iPhoneX(.portrait)))
    }

    @Test("MemoScreen contains no numeric-metric strings (G3)")
    func noNumericMetrics() {
      let host = UIHostingController(rootView: MemoScreen(viewModel: makeVM(), onFinished: {}))
      host.loadViewIfNeeded()
      host.view.frame = UIScreen.main.bounds
      host.view.layoutIfNeeded()
      let allText = collectText(in: host.view)
      for word in prohibitedWords {
        #expect(!allText.contains(word))
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

  private final class NoOpRepo: PhotoRepository, @unchecked Sendable {
    func todayPhoto(now: Date) async throws -> Photo? { nil }
    func insert(_ photo: Photo) async throws {}
  }
#endif
