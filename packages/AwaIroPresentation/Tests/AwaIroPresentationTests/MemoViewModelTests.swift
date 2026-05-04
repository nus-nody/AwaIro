import AwaIroDomain
import Foundation
import Testing

@testable import AwaIroPresentation

@Suite("MemoViewModel")
struct MemoViewModelTests {

  private static let url = URL(fileURLWithPath: "/tmp/test.jpg")
  private static let takenAt = Date(timeIntervalSince1970: 1_730_000_000)

  @Test("initial state is .editing with empty memo")
  @MainActor
  func initialState() {
    let vm = MemoViewModel(
      fileURL: Self.url,
      takenAt: Self.takenAt,
      recordPhoto: RecordPhotoUseCase(repository: FakeRepo()),
      cleanup: { _ in }
    )
    if case .editing(let memo) = vm.state {
      #expect(memo.isEmpty)
    } else {
      Issue.record("expected .editing, got \(vm.state)")
    }
  }

  @Test("setMemo updates editing state")
  @MainActor
  func setMemoUpdates() {
    let vm = MemoViewModel(
      fileURL: Self.url, takenAt: Self.takenAt,
      recordPhoto: RecordPhotoUseCase(repository: FakeRepo()),
      cleanup: { _ in }
    )
    vm.setMemo("morning walk")
    if case .editing(let memo) = vm.state {
      #expect(memo == "morning walk")
    } else {
      Issue.record("expected .editing, got \(vm.state)")
    }
  }

  @Test("save() with empty memo passes nil to use case")
  @MainActor
  func saveEmptyMemoPassesNil() async throws {
    let repo = FakeRepo()
    let vm = MemoViewModel(
      fileURL: Self.url, takenAt: Self.takenAt,
      recordPhoto: RecordPhotoUseCase(repository: repo),
      cleanup: { _ in }
    )
    await vm.save()
    if case .saved(let photo) = vm.state {
      #expect(photo.memo == nil)
    } else {
      Issue.record("expected .saved, got \(vm.state)")
    }
  }

  @Test("save() with non-empty memo passes it to use case")
  @MainActor
  func saveWithMemo() async {
    let repo = FakeRepo()
    let vm = MemoViewModel(
      fileURL: Self.url, takenAt: Self.takenAt,
      recordPhoto: RecordPhotoUseCase(repository: repo),
      cleanup: { _ in }
    )
    vm.setMemo("nuance")
    await vm.save()
    if case .saved(let photo) = vm.state {
      #expect(photo.memo == "nuance")
    } else {
      Issue.record("expected .saved, got \(vm.state)")
    }
  }

  @Test("save() failure transitions to .failed and keeps file (no cleanup call)")
  @MainActor
  func saveFailureNoCleanup() async {
    let repo = FakeRepo()
    repo.alreadyHasToday = true
    let counter = Counter()
    let vm = MemoViewModel(
      fileURL: Self.url, takenAt: Self.takenAt,
      recordPhoto: RecordPhotoUseCase(repository: repo),
      cleanup: { _ in counter.increment() }
    )
    await vm.save()
    if case .failed = vm.state {
      // ok
    } else {
      Issue.record("expected .failed, got \(vm.state)")
    }
    #expect(counter.value == 0)
  }

  @Test("cancel() invokes cleanup with file URL")
  @MainActor
  func cancelInvokesCleanup() async {
    let box = URLBox()
    let vm = MemoViewModel(
      fileURL: Self.url, takenAt: Self.takenAt,
      recordPhoto: RecordPhotoUseCase(repository: FakeRepo()),
      cleanup: { url in box.url = url }
    )
    await vm.cancel()
    #expect(box.url == Self.url)
  }
}

// MARK: - Helpers

private final class Counter: @unchecked Sendable {
  private(set) var value = 0
  func increment() { value += 1 }
}

private final class URLBox: @unchecked Sendable {
  var url: URL?
}

private final class FakeRepo: PhotoRepository, @unchecked Sendable {
  var alreadyHasToday = false
  var inserted: [Photo] = []

  func todayPhoto(now: Date) async throws -> Photo? {
    if alreadyHasToday {
      return Photo(
        id: UUID(), takenAt: now, fileURL: URL(fileURLWithPath: "/tmp/old.jpg"), memo: nil)
    }
    return nil
  }

  func insert(_ photo: Photo) async throws {
    inserted.append(photo)
  }
}
