import AwaIroDomain
import Foundation
import Testing

@testable import AwaIroPresentation

@Suite("PhotoDetailViewModel")
@MainActor
struct PhotoDetailViewModelTests {

  private func makePhoto(id: UUID = UUID(), memo: String? = "hello") -> Photo {
    let now = Date(timeIntervalSince1970: 1_730_000_000)
    return Photo(
      id: id, takenAt: now, developedAt: now.addingTimeInterval(-3600),
      fileURL: URL(fileURLWithPath: "/tmp/x.jpg"), memo: memo)
  }

  @Test("initial state shows photo in viewing mode")
  func initialViewing() {
    let photo = makePhoto()
    let repo = FakeRepo(seed: [photo])
    let usecase = UpdateMemoUseCase(repository: repo)
    let vm = PhotoDetailViewModel(photo: photo, updateMemo: usecase)

    if case .viewing(let p) = vm.state {
      #expect(p.id == photo.id)
    } else {
      Issue.record("expected viewing")
    }
  }

  @Test("startEditing transitions to editing with current memo")
  func startEditing() {
    let photo = makePhoto(memo: "before")
    let repo = FakeRepo(seed: [photo])
    let usecase = UpdateMemoUseCase(repository: repo)
    let vm = PhotoDetailViewModel(photo: photo, updateMemo: usecase)

    vm.startEditing()
    if case .editing(_, let draft) = vm.state {
      #expect(draft == "before")
    } else {
      Issue.record("expected editing")
    }
  }

  @Test("setDraft updates the editing draft")
  func setDraftUpdates() {
    let photo = makePhoto(memo: "before")
    let repo = FakeRepo(seed: [photo])
    let vm = PhotoDetailViewModel(photo: photo, updateMemo: UpdateMemoUseCase(repository: repo))

    vm.startEditing()
    vm.setDraft("after")

    if case .editing(_, let draft) = vm.state {
      #expect(draft == "after")
    } else {
      Issue.record("expected editing")
    }
  }

  @Test("save persists memo via use case and returns to viewing")
  func saveEditPersists() async {
    let photo = makePhoto(memo: "before")
    let repo = FakeRepo(seed: [photo])
    let usecase = UpdateMemoUseCase(repository: repo)
    let vm = PhotoDetailViewModel(photo: photo, updateMemo: usecase)

    vm.startEditing()
    vm.setDraft("after")
    await vm.save()

    if case .viewing(let updated) = vm.state {
      #expect(updated.memo == "after")
    } else {
      Issue.record("expected viewing after save")
    }
    let stored = try? await repo.findById(photo.id)
    #expect(stored?.memo == "after")
  }

  @Test("save with empty draft persists nil memo")
  func saveEmptyDraftAsNil() async {
    let photo = makePhoto(memo: "before")
    let repo = FakeRepo(seed: [photo])
    let usecase = UpdateMemoUseCase(repository: repo)
    let vm = PhotoDetailViewModel(photo: photo, updateMemo: usecase)

    vm.startEditing()
    vm.setDraft("")
    await vm.save()

    if case .viewing(let updated) = vm.state {
      #expect(updated.memo == nil)
    }
  }

  @Test("cancelEditing reverts to viewing without saving")
  func cancelKeepsOriginal() async {
    let photo = makePhoto(memo: "before")
    let repo = FakeRepo(seed: [photo])
    let vm = PhotoDetailViewModel(photo: photo, updateMemo: UpdateMemoUseCase(repository: repo))

    vm.startEditing()
    vm.setDraft("changed")
    vm.cancelEditing()

    if case .viewing(let p) = vm.state {
      #expect(p.memo == "before")
    }
  }
}

private final class FakeRepo: PhotoRepository, @unchecked Sendable {
  private var photos: [Photo]
  init(seed: [Photo]) { self.photos = seed }
  func todayPhoto(now: Date) async throws -> Photo? { nil }
  func insert(_ photo: Photo) async throws { photos.append(photo) }
  func findAllOrderByTakenAtDesc() async throws -> [Photo] { photos }
  func findById(_ id: UUID) async throws -> Photo? { photos.first { $0.id == id } }
  func updateMemo(id: UUID, memo: String?) async throws {
    if let idx = photos.firstIndex(where: { $0.id == id }) {
      let p = photos[idx]
      photos[idx] = Photo(
        id: p.id, takenAt: p.takenAt, developedAt: p.developedAt,
        fileURL: p.fileURL, memo: memo)
    }
  }
}
