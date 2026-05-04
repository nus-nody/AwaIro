# Phase 2 Sprint 1 Record Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** AwaIro の中核体験「泡を通して 1 日 1 枚撮影 → メモを添えて保存」を iOS ネイティブで完成させる。HomeScreen は BubbleCameraView（カメラプレビュー + 球面歪み + タップで撮影）を表示し、撮影後 MemoScreen に遷移、保存後は Home に戻り「グレー泡」状態（今日撮影済）になる。

**Architecture:** Phase 1 で確立した Clean Arch + SPM 4 パッケージに、Camera (AVFoundation actor) / 球面歪み (SwiftUI `Shader` API による Metal インライン) / RecordPhotoUseCase (G1 guardrail) / MemoScreen を追加。Navigation は NavigationStack の path-based 遷移。Camera permission は Info.plist + AVCaptureDevice.requestAccess を Platform 層に隔離。Simulator では実カメラなしで preview が黒画面になるが、それは正常動作（実機 verify は最終 Phase で人が確認）。

**Tech Stack:** Swift 6 / SwiftUI + `Shader` (Metal inline, iOS 17+) / AVFoundation (camera) / Swift Concurrency (actor) / Swift Testing / swift-snapshot-testing

**Spec:** [Sprint 1 Record Design](../specs/2026-04-25-sprint-1-record-design.md), [Conversion Spec § Phase 2](../specs/2026-05-04-kmp-to-ios-conversion-design.md), [Concept Guardrails G1/G3/G4](../../docs/concept-guardrails.md)

---

## File Structure

### Created in this Phase

```
packages/AwaIroDomain/Sources/AwaIroDomain/
├── Models/
│   └── RecordPhotoError.swift              # G1 violation case + IO failure case
└── UseCases/
    └── RecordPhotoUseCase.swift            # G1 guardrail enforcement + insert

packages/AwaIroDomain/Tests/AwaIroDomainTests/
└── RecordPhotoUseCaseTests.swift           # G1 enforcement tests

packages/AwaIroPlatform/Sources/AwaIroPlatform/
├── Files/
│   └── PhotoFileStore.swift                # writes Data → URL under photoDirectory
├── Camera/
│   ├── CameraPermission.swift              # protocol + AVFoundation impl
│   ├── CameraPermissionStatus.swift        # value type for VM consumption
│   └── CameraController.swift              # actor wrapping AVCaptureSession + AVCapturePhotoOutput
└── Effects/
    └── BubbleDistortion.swift              # SwiftUI ViewModifier using Shader API + .metal

packages/AwaIroPlatform/Sources/AwaIroPlatform/Effects/
└── BubbleDistortion.metal                  # MSL shader source for sphere distortion

packages/AwaIroPlatform/Tests/AwaIroPlatformTests/
├── PhotoFileStoreTests.swift               # write/read/cleanup
├── CameraPermissionStatusTests.swift       # value type behaviors
└── BubbleDistortionSnapshotTests.swift     # snapshot test on static image (iOS only)

packages/AwaIroPresentation/Sources/AwaIroPresentation/
├── Home/
│   └── BubbleCameraView.swift              # UIViewRepresentable + .layerEffect + tap
├── Memo/
│   ├── MemoViewModel.swift                 # @Observable: state machine + save action
│   └── MemoScreen.swift                    # SwiftUI: photo + memo input + buttons
└── Navigation/
    └── AppRoute.swift                      # enum: home / memo(URL, Date)

packages/AwaIroPresentation/Tests/AwaIroPresentationTests/
├── MemoViewModelTests.swift
└── MemoScreenSnapshotTests.swift           # iOS only

App/AwaIro/
├── AwaIroApp.swift                         # MODIFIED: NavigationStack with AppRoute
├── AppContainer.swift                      # MODIFIED: + CameraController + PhotoFileStore + RecordPhotoUseCase factories
├── RootContentView.swift                   # MODIFIED: NavigationStack(path:) routing
└── Info.plist                              # NEW: Xcode auto-generated, manually edited to add NSCameraUsageDescription

App/AwaIro.xcodeproj/project.pbxproj        # MODIFIED: + new source files registered, + Info.plist key surfaced via INFOPLIST_KEY_NSCameraUsageDescription build setting
```

### Modified in this Phase

```
packages/AwaIroPlatform/Sources/AwaIroPlatform/Files/FilePathProvider.swift
  + photoDirectory: URL                     # creates and returns ApplicationSupport/AwaIro/photos

packages/AwaIroPresentation/Sources/AwaIroPresentation/Home/HomeViewModel.swift
  + recordPhoto(url:takenAt:memo:) async    # calls RecordPhotoUseCase, updates state

packages/AwaIroPresentation/Sources/AwaIroPresentation/Home/HomeScreen.swift
  Replace placeholder Circle with BubbleCameraView when state == .unrecorded;
  keep grayed visual for .recorded; surface tap → onCaptured callback

packages/AwaIroPresentation/Sources/AwaIroPresentation/Home/HomeContentView.swift
  Adapt to take an optional preview-content View so snapshot tests
  can inject a static placeholder instead of the live camera

App/AwaIro/AwaIroApp.swift                  # navigation host wiring
App/AwaIro/RootContentView.swift            # path-based NavigationStack
docs/snapshots/phase-2/                     # screenshot artifacts
README.md                                   # mark Phase 2 ✅
docs/harness/phase2-retro.md                # NEW (Task 22)
```

---

## Conventions for All Tasks

- **TDD**: Red (failing test) → Verify Red → Green (impl) → Verify Green → Commit
- **Commit message**: Conventional Commit + `Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>` trailer (commit-trailer-warn hook will warn if missing)
- **HOTL by default**: commit locally, never push. Push at end via HITL_BYPASS=1.
- **HITL operations** (orchestrator handles directly):
  - Task 17: Info.plist edit (use `.claude/hooks/.bypass-next-edit` marker)
  - Task 17 also: project.pbxproj edit to add new source files (use marker)
- **Concept Guardrails enforced**:
  - G1 (1日1枚) — RecordPhotoUseCase + tests
  - G3 (数字なし) — preserved by construction in MemoScreen + snapshot test
  - G4 (通知禁止) — Info.plist must NOT add Push entitlements (only NSCameraUsageDescription)

---

## Task 1: Domain — RecordPhotoError types

**Files:**
- Create: `packages/AwaIroDomain/Sources/AwaIroDomain/Models/RecordPhotoError.swift`

Pure Swift error enum. No tests (data-only, exercised via Task 2).

- [ ] **Step 1: Implement**

Create `packages/AwaIroDomain/Sources/AwaIroDomain/Models/RecordPhotoError.swift`:

```swift
import Foundation

public enum RecordPhotoError: Error, Equatable, Sendable {
    /// G1 guardrail: a photo was already recorded today (device-local calendar day).
    case alreadyRecordedToday

    /// Repository write failed (forwarded from Data layer).
    case repositoryFailure(message: String)
}
```

- [ ] **Step 2: Verify package builds**

```bash
cd packages/AwaIroDomain && swift build 2>&1 | tail -3
```

Expected: clean build.

- [ ] **Step 3: Commit**

```bash
cd /Users/nodayouta/Documents/code/AwaIro/.claude/worktrees/hardcore-mccarthy-b2a51f
git add packages/AwaIroDomain/Sources/AwaIroDomain/Models/RecordPhotoError.swift
git commit -m "$(cat <<'EOF'
feat(domain): add RecordPhotoError enum

Two cases: alreadyRecordedToday (G1 guardrail) and
repositoryFailure(message:) for forwarded data-layer errors.
Equatable + Sendable so VMs and tests can match cleanly.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: Domain — RecordPhotoUseCase + G1 guardrail tests

**Files:**
- Create: `packages/AwaIroDomain/Sources/AwaIroDomain/UseCases/RecordPhotoUseCase.swift`
- Create: `packages/AwaIroDomain/Tests/AwaIroDomainTests/RecordPhotoUseCaseTests.swift`

The G1 enforcement point: refuses to insert if a photo already exists for today's calendar day.

- [ ] **Step 1: Write failing test**

Create `packages/AwaIroDomain/Tests/AwaIroDomainTests/RecordPhotoUseCaseTests.swift`:

```swift
import Foundation
import Testing
@testable import AwaIroDomain

@Suite("RecordPhotoUseCase — G1 (1日1枚)")
struct RecordPhotoUseCaseTests {

    @Test("inserts when no photo exists for today")
    func insertsWhenEmpty() async throws {
        let repo = FakePhotoRepository()
        let usecase = RecordPhotoUseCase(repository: repo)

        let now = Date(timeIntervalSince1970: 1_730_000_000)
        let url = URL(fileURLWithPath: "/tmp/x.jpg")

        let saved = try await usecase.execute(fileURL: url, takenAt: now, memo: "morning")

        #expect(saved.fileURL == url)
        #expect(saved.takenAt == now)
        #expect(saved.memo == "morning")
        #expect(repo.inserted.count == 1)
    }

    @Test("refuses second photo on the same calendar day")
    func refusesSameDay() async throws {
        let repo = FakePhotoRepository()
        let usecase = RecordPhotoUseCase(repository: repo)
        let cal = Calendar.current

        // First photo at 09:00
        let morning = cal.date(from: DateComponents(year: 2026, month: 5, day: 4, hour: 9))!
        _ = try await usecase.execute(fileURL: URL(fileURLWithPath: "/tmp/a.jpg"), takenAt: morning, memo: nil)

        // Second photo at 23:00 same day
        let evening = cal.date(from: DateComponents(year: 2026, month: 5, day: 4, hour: 23))!
        await #expect(throws: RecordPhotoError.alreadyRecordedToday) {
            _ = try await usecase.execute(fileURL: URL(fileURLWithPath: "/tmp/b.jpg"), takenAt: evening, memo: nil)
        }

        #expect(repo.inserted.count == 1) // only the first one persisted
    }

    @Test("accepts photo on next calendar day")
    func acceptsNextDay() async throws {
        let repo = FakePhotoRepository()
        let usecase = RecordPhotoUseCase(repository: repo)
        let cal = Calendar.current

        let day1 = cal.date(from: DateComponents(year: 2026, month: 5, day: 4, hour: 12))!
        _ = try await usecase.execute(fileURL: URL(fileURLWithPath: "/tmp/a.jpg"), takenAt: day1, memo: nil)

        let day2 = cal.date(from: DateComponents(year: 2026, month: 5, day: 5, hour: 12))!
        let saved2 = try await usecase.execute(fileURL: URL(fileURLWithPath: "/tmp/b.jpg"), takenAt: day2, memo: "next")

        #expect(saved2.memo == "next")
        #expect(repo.inserted.count == 2)
    }

    @Test("accepts midnight-crossing as a new day (23:59 then 00:00)")
    func acceptsMidnightCrossing() async throws {
        let repo = FakePhotoRepository()
        let usecase = RecordPhotoUseCase(repository: repo)
        let cal = Calendar.current

        let dec31 = cal.date(from: DateComponents(year: 2025, month: 12, day: 31, hour: 23, minute: 59))!
        _ = try await usecase.execute(fileURL: URL(fileURLWithPath: "/tmp/a.jpg"), takenAt: dec31, memo: nil)

        let jan1 = cal.date(from: DateComponents(year: 2026, month: 1, day: 1, hour: 0, minute: 0))!
        let saved2 = try await usecase.execute(fileURL: URL(fileURLWithPath: "/tmp/b.jpg"), takenAt: jan1, memo: nil)

        #expect(saved2.takenAt == jan1)
        #expect(repo.inserted.count == 2)
    }

    @Test("forwards repository failure as repositoryFailure")
    func forwardsRepositoryError() async {
        struct Boom: Error {}
        let repo = FakePhotoRepository(insertError: Boom())
        let usecase = RecordPhotoUseCase(repository: repo)

        await #expect(throws: RecordPhotoError.self) {
            _ = try await usecase.execute(fileURL: URL(fileURLWithPath: "/tmp/x.jpg"), takenAt: Date(), memo: nil)
        }
    }
}

// MARK: - Fake repository

private final class FakePhotoRepository: PhotoRepository, @unchecked Sendable {
    private(set) var inserted: [Photo] = []
    private let insertError: (any Error)?

    init(insertError: (any Error)? = nil) {
        self.insertError = insertError
    }

    func todayPhoto(now: Date) async throws -> Photo? {
        let cal = Calendar.current
        let startOfDay = cal.startOfDay(for: now)
        let endOfDay = cal.date(byAdding: .day, value: 1, to: startOfDay)!
        return inserted.first { $0.takenAt >= startOfDay && $0.takenAt < endOfDay }
    }

    func insert(_ photo: Photo) async throws {
        if let insertError { throw RecordPhotoError.repositoryFailure(message: String(describing: insertError)) }
        inserted.append(photo)
    }
}
```

- [ ] **Step 2: Run to verify FAIL**

```bash
cd packages/AwaIroDomain && swift test --filter RecordPhotoUseCaseTests 2>&1 | tail -10
```

Expected: FAIL — RecordPhotoUseCase not found.

- [ ] **Step 3: Implement**

Create `packages/AwaIroDomain/Sources/AwaIroDomain/UseCases/RecordPhotoUseCase.swift`:

```swift
import Foundation

public struct RecordPhotoUseCase: Sendable {
    private let repository: any PhotoRepository

    public init(repository: any PhotoRepository) {
        self.repository = repository
    }

    /// Inserts a new photo if no photo exists for today's calendar day.
    /// G1 guardrail: throws .alreadyRecordedToday if a photo already exists.
    /// Repository failures are wrapped in .repositoryFailure(message:).
    public func execute(fileURL: URL, takenAt: Date, memo: String?) async throws -> Photo {
        if try await repository.todayPhoto(now: takenAt) != nil {
            throw RecordPhotoError.alreadyRecordedToday
        }

        let photo = Photo(
            id: UUID(),
            takenAt: takenAt,
            fileURL: fileURL,
            memo: memo
        )

        do {
            try await repository.insert(photo)
        } catch let recordError as RecordPhotoError {
            throw recordError
        } catch {
            throw RecordPhotoError.repositoryFailure(message: String(describing: error))
        }

        return photo
    }
}
```

- [ ] **Step 4: Verify PASS**

```bash
cd packages/AwaIroDomain && swift test --filter RecordPhotoUseCaseTests 2>&1 | tail -10
```

Expected: 5 tests passed.

- [ ] **Step 5: Commit**

```bash
cd /Users/nodayouta/Documents/code/AwaIro/.claude/worktrees/hardcore-mccarthy-b2a51f
git add packages/AwaIroDomain/Sources/AwaIroDomain/UseCases/RecordPhotoUseCase.swift packages/AwaIroDomain/Tests/AwaIroDomainTests/RecordPhotoUseCaseTests.swift
git commit -m "$(cat <<'EOF'
feat(domain): add RecordPhotoUseCase enforcing G1 (1日1枚)

Refuses to insert when repo.todayPhoto(now: takenAt) returns a Photo,
throwing .alreadyRecordedToday. On insert failure, wraps the underlying
error in .repositoryFailure(message:) so VMs can render it. 5 tests
cover empty / same-day / next-day / midnight-crossing / repo-error.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: Platform — extend FilePathProvider with photoDirectory

**Files:**
- Modify: `packages/AwaIroPlatform/Sources/AwaIroPlatform/Files/FilePathProvider.swift`
- Modify: `packages/AwaIroPlatform/Tests/AwaIroPlatformTests/FilePathProviderTests.swift`

Add a `photoDirectory: URL` property that returns `<root>/photos/`, ensuring the directory exists.

- [ ] **Step 1: Add failing test**

Append to `packages/AwaIroPlatform/Tests/AwaIroPlatformTests/FilePathProviderTests.swift` (inside the `FilePathProviderTests` suite):

```swift
    @Test("photoDirectory is under root and exists after access")
    func photoDirectoryExists() throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("awairo-test-\(UUID().uuidString)")
        let provider = FilePathProvider(rootDirectory: tmp)
        let dir = provider.photoDirectory
        #expect(dir.path.hasPrefix(tmp.path))
        #expect(dir.lastPathComponent == "photos")
        var isDir: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: dir.path, isDirectory: &isDir)
        #expect(exists && isDir.boolValue)
    }
```

- [ ] **Step 2: Run to verify FAIL**

```bash
cd packages/AwaIroPlatform && swift test --filter photoDirectoryExists 2>&1 | tail -10
```

Expected: FAIL — `photoDirectory` not found.

- [ ] **Step 3: Implement**

In `packages/AwaIroPlatform/Sources/AwaIroPlatform/Files/FilePathProvider.swift`, add the new property after `databaseURL`:

```swift
    public var photoDirectory: URL {
        let dir = rootDirectory.appendingPathComponent("photos", isDirectory: true)
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
```

Wait — Phase 1 dropped the injectable `fileManager` for Sendable reasons. Use the same pattern as `databaseURL`: call `FileManager.default` directly inside `ensureRootExists`-style helper.

Replace the existing `databaseURL` and `ensureRootExists()` with this consolidated version (keeps fileManager-less Sendable conformance):

```swift
    public var databaseURL: URL {
        ensureDirectory(rootDirectory)
        return rootDirectory.appendingPathComponent("awairo.sqlite")
    }

    public var photoDirectory: URL {
        let dir = rootDirectory.appendingPathComponent("photos", isDirectory: true)
        ensureDirectory(dir)
        return dir
    }

    private func ensureDirectory(_ url: URL) {
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }
```

- [ ] **Step 4: Verify PASS**

```bash
cd packages/AwaIroPlatform && swift test 2>&1 | tail -10
```

Expected: 3 tests passing (previous 2 + the new `photoDirectoryExists`).

- [ ] **Step 5: Commit**

```bash
cd /Users/nodayouta/Documents/code/AwaIro/.claude/worktrees/hardcore-mccarthy-b2a51f
git add packages/AwaIroPlatform/Sources/AwaIroPlatform/Files/FilePathProvider.swift packages/AwaIroPlatform/Tests/AwaIroPlatformTests/FilePathProviderTests.swift
git commit -m "$(cat <<'EOF'
feat(platform): add photoDirectory to FilePathProvider

photoDirectory returns <root>/photos/, auto-creating the directory.
Used by PhotoFileStore (next task) to write captured photo files.
Refactored ensureRootExists to a generic ensureDirectory(_:) helper
shared with databaseURL.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 4: Platform — PhotoFileStore

**Files:**
- Create: `packages/AwaIroPlatform/Sources/AwaIroPlatform/Files/PhotoFileStore.swift`
- Create: `packages/AwaIroPlatform/Tests/AwaIroPlatformTests/PhotoFileStoreTests.swift`

Writes captured `Data` to a JPEG file under `photoDirectory`, returns the file URL. Also supports `delete(at:)` for cancel-cleanup.

- [ ] **Step 1: Write failing test**

Create `packages/AwaIroPlatform/Tests/AwaIroPlatformTests/PhotoFileStoreTests.swift`:

```swift
import Foundation
import Testing
@testable import AwaIroPlatform

@Suite("PhotoFileStore")
struct PhotoFileStoreTests {

    private func makeStore() throws -> (PhotoFileStore, FilePathProvider) {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("awairo-photo-test-\(UUID().uuidString)")
        let provider = FilePathProvider(rootDirectory: tmp)
        return (PhotoFileStore(filePathProvider: provider), provider)
    }

    @Test("write returns a URL under photoDirectory and the file is readable")
    func writeRoundTrip() throws {
        let (store, provider) = try makeStore()
        let data = Data([0xFF, 0xD8, 0xFF, 0xE0]) // JPEG magic prefix
        let id = UUID()
        let url = try store.write(data: data, photoId: id)
        #expect(url.path.hasPrefix(provider.photoDirectory.path))
        #expect(url.lastPathComponent.hasPrefix(id.uuidString))
        let read = try Data(contentsOf: url)
        #expect(read == data)
    }

    @Test("write produces .jpg extension")
    func extensionIsJpg() throws {
        let (store, _) = try makeStore()
        let url = try store.write(data: Data([0xFF, 0xD8]), photoId: UUID())
        #expect(url.pathExtension == "jpg")
    }

    @Test("delete removes the file")
    func deleteRemoves() throws {
        let (store, _) = try makeStore()
        let url = try store.write(data: Data([0xFF, 0xD8]), photoId: UUID())
        #expect(FileManager.default.fileExists(atPath: url.path))
        try store.delete(at: url)
        #expect(!FileManager.default.fileExists(atPath: url.path))
    }

    @Test("delete on missing file does not throw (idempotent)")
    func deleteIdempotent() throws {
        let (store, provider) = try makeStore()
        let bogus = provider.photoDirectory.appendingPathComponent("nonexistent.jpg")
        // Should not throw
        try store.delete(at: bogus)
    }
}
```

- [ ] **Step 2: Run to verify FAIL**

```bash
cd packages/AwaIroPlatform && swift test --filter PhotoFileStoreTests 2>&1 | tail -10
```

Expected: FAIL — PhotoFileStore not found.

- [ ] **Step 3: Implement**

Create `packages/AwaIroPlatform/Sources/AwaIroPlatform/Files/PhotoFileStore.swift`:

```swift
import Foundation

public struct PhotoFileStore: Sendable {
    private let filePathProvider: FilePathProvider

    public init(filePathProvider: FilePathProvider) {
        self.filePathProvider = filePathProvider
    }

    /// Writes JPEG data for a photo to disk and returns the file URL.
    /// File name format: <uuid>.jpg under FilePathProvider.photoDirectory.
    public func write(data: Data, photoId: UUID) throws -> URL {
        let url = filePathProvider.photoDirectory
            .appendingPathComponent("\(photoId.uuidString).jpg")
        try data.write(to: url, options: .atomic)
        return url
    }

    /// Removes a previously-written photo file. Idempotent: missing file is not an error.
    public func delete(at url: URL) throws {
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }
}
```

- [ ] **Step 4: Verify PASS**

```bash
cd packages/AwaIroPlatform && swift test --filter PhotoFileStoreTests 2>&1 | tail -10
```

Expected: 4 tests passed.

- [ ] **Step 5: Commit**

```bash
cd /Users/nodayouta/Documents/code/AwaIro/.claude/worktrees/hardcore-mccarthy-b2a51f
git add packages/AwaIroPlatform/Sources/AwaIroPlatform/Files/PhotoFileStore.swift packages/AwaIroPlatform/Tests/AwaIroPlatformTests/PhotoFileStoreTests.swift
git commit -m "$(cat <<'EOF'
feat(platform): add PhotoFileStore for writing captured JPEG to disk

Writes photo data as <uuid>.jpg under FilePathProvider.photoDirectory.
delete(at:) is idempotent so the cancel-cleanup path in MemoScreen can
safely call it without checking existence first.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 5: Platform — CameraPermissionStatus value type

**Files:**
- Create: `packages/AwaIroPlatform/Sources/AwaIroPlatform/Camera/CameraPermissionStatus.swift`
- Create: `packages/AwaIroPlatform/Tests/AwaIroPlatformTests/CameraPermissionStatusTests.swift`

Pure value type that VMs can switch on. Decouples Domain/Presentation from `AVAuthorizationStatus`.

- [ ] **Step 1: Create directory**

```bash
mkdir -p packages/AwaIroPlatform/Sources/AwaIroPlatform/Camera
```

- [ ] **Step 2: Write failing test**

Create `packages/AwaIroPlatform/Tests/AwaIroPlatformTests/CameraPermissionStatusTests.swift`:

```swift
import Testing
@testable import AwaIroPlatform

@Suite("CameraPermissionStatus")
struct CameraPermissionStatusTests {
    @Test("isUsable is true only for .authorized")
    func isUsable() {
        #expect(CameraPermissionStatus.authorized.isUsable)
        #expect(!CameraPermissionStatus.notDetermined.isUsable)
        #expect(!CameraPermissionStatus.denied.isUsable)
        #expect(!CameraPermissionStatus.restricted.isUsable)
    }

    @Test("requiresPrompt is true only for .notDetermined")
    func requiresPrompt() {
        #expect(CameraPermissionStatus.notDetermined.requiresPrompt)
        #expect(!CameraPermissionStatus.authorized.requiresPrompt)
        #expect(!CameraPermissionStatus.denied.requiresPrompt)
        #expect(!CameraPermissionStatus.restricted.requiresPrompt)
    }
}
```

- [ ] **Step 3: Verify FAIL**

```bash
cd packages/AwaIroPlatform && swift test --filter CameraPermissionStatusTests 2>&1 | tail -10
```

Expected: FAIL — type not found.

- [ ] **Step 4: Implement**

Create `packages/AwaIroPlatform/Sources/AwaIroPlatform/Camera/CameraPermissionStatus.swift`:

```swift
import Foundation

public enum CameraPermissionStatus: Equatable, Sendable {
    case notDetermined
    case authorized
    case denied
    case restricted

    public var isUsable: Bool {
        self == .authorized
    }

    public var requiresPrompt: Bool {
        self == .notDetermined
    }
}
```

- [ ] **Step 5: Verify PASS**

```bash
cd packages/AwaIroPlatform && swift test --filter CameraPermissionStatusTests 2>&1 | tail -10
```

Expected: 2 tests passed.

- [ ] **Step 6: Commit**

```bash
cd /Users/nodayouta/Documents/code/AwaIro/.claude/worktrees/hardcore-mccarthy-b2a51f
git add packages/AwaIroPlatform/Sources/AwaIroPlatform/Camera/CameraPermissionStatus.swift packages/AwaIroPlatform/Tests/AwaIroPlatformTests/CameraPermissionStatusTests.swift
git commit -m "$(cat <<'EOF'
feat(platform): add CameraPermissionStatus value type

Pure Swift enum decoupling Domain / Presentation from AVAuthorizationStatus.
Cases: notDetermined / authorized / denied / restricted.
Convenience: isUsable (only authorized) and requiresPrompt (only
notDetermined). Used by HomeViewModel to decide whether to render
BubbleCameraView, the prompt-trigger overlay, or the denied fallback.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 6: Platform — CameraPermission protocol + AVFoundation impl

**Files:**
- Create: `packages/AwaIroPlatform/Sources/AwaIroPlatform/Camera/CameraPermission.swift`

Protocol so VMs can be tested with a fake. AVFoundation impl is iOS-only via `#if canImport(AVFoundation)`.

- [ ] **Step 1: Implement**

Create `packages/AwaIroPlatform/Sources/AwaIroPlatform/Camera/CameraPermission.swift`:

```swift
import Foundation

public protocol CameraPermission: Sendable {
    /// Current permission status — synchronous (no prompt).
    func currentStatus() async -> CameraPermissionStatus

    /// If the current status is .notDetermined, prompts the user and
    /// returns the resulting status. If already determined, returns it
    /// without re-prompting.
    func requestIfNeeded() async -> CameraPermissionStatus
}

#if canImport(AVFoundation)
import AVFoundation

public struct AVFoundationCameraPermission: CameraPermission {
    public init() {}

    public func currentStatus() async -> CameraPermissionStatus {
        Self.translate(AVCaptureDevice.authorizationStatus(for: .video))
    }

    public func requestIfNeeded() async -> CameraPermissionStatus {
        let current = AVCaptureDevice.authorizationStatus(for: .video)
        if current != .notDetermined {
            return Self.translate(current)
        }
        let granted = await AVCaptureDevice.requestAccess(for: .video)
        return granted ? .authorized : .denied
    }

    private static func translate(_ status: AVAuthorizationStatus) -> CameraPermissionStatus {
        switch status {
        case .notDetermined: return .notDetermined
        case .authorized: return .authorized
        case .denied: return .denied
        case .restricted: return .restricted
        @unknown default: return .denied
        }
    }
}
#endif
```

No tests for the AVFoundation impl directly — it wraps Apple API. The protocol is exercised by HomeViewModelTests via fakes (Task 11).

- [ ] **Step 2: Verify build (macOS — only protocol compiles, AVFoundation impl is gated)**

```bash
cd packages/AwaIroPlatform && swift build 2>&1 | tail -3
```

Expected: clean build.

- [ ] **Step 3: Commit**

```bash
cd /Users/nodayouta/Documents/code/AwaIro/.claude/worktrees/hardcore-mccarthy-b2a51f
git add packages/AwaIroPlatform/Sources/AwaIroPlatform/Camera/CameraPermission.swift
git commit -m "$(cat <<'EOF'
feat(platform): add CameraPermission protocol + AVFoundation impl

Protocol with currentStatus() and requestIfNeeded() — both async to
match Swift Concurrency idioms. AVFoundationCameraPermission gated by
#if canImport(AVFoundation) so macOS builds (used by swift test) skip
it cleanly. VMs depend only on the protocol, fakes drive tests.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 7: Platform — CameraController actor + protocol

**Files:**
- Create: `packages/AwaIroPlatform/Sources/AwaIroPlatform/Camera/CameraController.swift`

`CameraController` is a protocol; `AVFoundationCameraController` is the actor-isolated impl that owns an `AVCaptureSession` and `AVCapturePhotoOutput`. Public surface:
- `start() async throws`: configures session and starts running
- `stop() async`: stops the session
- `capture() async throws -> Data`: triggers photo capture, returns JPEG data
- `previewLayer: AVCaptureVideoPreviewLayer`: exposed for SwiftUI UIViewRepresentable

The protocol allows fakes; the impl is iOS-only.

- [ ] **Step 1: Implement**

Create `packages/AwaIroPlatform/Sources/AwaIroPlatform/Camera/CameraController.swift`:

```swift
import Foundation

#if canImport(AVFoundation)
import AVFoundation

public protocol CameraController: Sendable {
    func start() async throws
    func stop() async
    func capture() async throws -> Data
    /// The preview layer to embed in SwiftUI via UIViewRepresentable. Main-actor
    /// access expected.
    @MainActor var previewLayer: AVCaptureVideoPreviewLayer { get }
}

public enum CameraControllerError: Error, Sendable {
    case noBackCamera
    case sessionConfigurationFailed
    case captureFailed(message: String)
}

public actor AVFoundationCameraController: CameraController {
    private let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    @MainActor public let previewLayer: AVCaptureVideoPreviewLayer

    public init() {
        // previewLayer must be created on the main actor (UIKit object).
        self.previewLayer = AVCaptureVideoPreviewLayer()
        Task { @MainActor [previewLayer, session] in
            previewLayer.session = session
            previewLayer.videoGravity = .resizeAspectFill
        }
    }

    public func start() async throws {
        if session.isRunning { return }
        session.beginConfiguration()
        defer { session.commitConfiguration() }

        session.sessionPreset = .photo

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            throw CameraControllerError.noBackCamera
        }
        if session.inputs.isEmpty {
            session.addInput(input)
        }

        if session.canAddOutput(photoOutput), session.outputs.isEmpty {
            session.addOutput(photoOutput)
        }

        session.startRunning()
    }

    public func stop() async {
        if session.isRunning { session.stopRunning() }
    }

    public func capture() async throws -> Data {
        let settings = AVCapturePhotoSettings()
        let delegate = PhotoCaptureDelegate()
        photoOutput.capturePhoto(with: settings, delegate: delegate)
        return try await delegate.dataResult()
    }
}

/// Bridges AVCapturePhotoCaptureDelegate (callback-based) to async/await.
private final class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate, @unchecked Sendable {
    private var continuation: CheckedContinuation<Data, any Error>?

    func dataResult() async throws -> Data {
        try await withCheckedThrowingContinuation { cont in
            self.continuation = cont
        }
    }

    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishProcessingPhoto photo: AVCapturePhoto,
                     error: (any Error)?) {
        if let error {
            continuation?.resume(throwing: CameraControllerError.captureFailed(message: String(describing: error)))
            continuation = nil
            return
        }
        guard let data = photo.fileDataRepresentation() else {
            continuation?.resume(throwing: CameraControllerError.captureFailed(message: "fileDataRepresentation returned nil"))
            continuation = nil
            return
        }
        continuation?.resume(returning: data)
        continuation = nil
    }
}
#endif
```

- [ ] **Step 2: Verify build**

```bash
cd packages/AwaIroPlatform && swift build 2>&1 | tail -3
```

Expected: clean build.

- [ ] **Step 3: Commit**

```bash
cd /Users/nodayouta/Documents/code/AwaIro/.claude/worktrees/hardcore-mccarthy-b2a51f
git add packages/AwaIroPlatform/Sources/AwaIroPlatform/Camera/CameraController.swift
git commit -m "$(cat <<'EOF'
feat(platform): add CameraController protocol + AVFoundation actor impl

Protocol surface: start/stop/capture (async) and @MainActor previewLayer
(AVCaptureVideoPreviewLayer needs main-actor isolation to integrate
with SwiftUI UIViewRepresentable).

AVFoundationCameraController:
- actor wraps AVCaptureSession + AVCapturePhotoOutput (mutable shared
  state isolation)
- start() configures back wide-angle camera + photo output, idempotent
- capture() bridges AVCapturePhotoCaptureDelegate callbacks to
  async/await via CheckedContinuation
- session preset .photo for full-resolution capture

iOS-only via #if canImport(AVFoundation). Tests use fake conforming to
the protocol — AVFoundation API itself is too coupled to system to
mock meaningfully.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 8: Platform — BubbleDistortion shader (.metal + ViewModifier)

**Files:**
- Create: `packages/AwaIroPlatform/Sources/AwaIroPlatform/Effects/BubbleDistortion.metal`
- Create: `packages/AwaIroPlatform/Sources/AwaIroPlatform/Effects/BubbleDistortion.swift`

SwiftUI `Shader` API (iOS 17+) lets us write Metal Shading Language inline-resourced through SPM. The shader takes a sample position and returns a sphere-distorted sample of the source.

- [ ] **Step 1: Create directory**

```bash
mkdir -p packages/AwaIroPlatform/Sources/AwaIroPlatform/Effects
```

- [ ] **Step 2: Write the MSL shader**

Create `packages/AwaIroPlatform/Sources/AwaIroPlatform/Effects/BubbleDistortion.metal`:

```metal
#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

/// Sphere distortion: maps a circular region centered at `center`
/// with radius `radius` to a refracted bubble-like view.
/// Outside the circle: passes through unchanged.
/// Inside: applies a barrel distortion proportional to distance from center.
[[ stitchable ]] half4 bubbleDistortion(
    float2 position,
    SwiftUI::Layer layer,
    float2 size,
    float radius,
    float strength
) {
    float2 center = size * 0.5;
    float2 toCenter = position - center;
    float dist = length(toCenter);

    if (dist >= radius) {
        return layer.sample(position);
    }

    // Normalized distance in [0..1]
    float u = dist / radius;
    // Barrel distortion: sample a point closer to center
    float displaceFactor = strength * (1.0 - u * u);
    float2 sampled = center + toCenter * (1.0 - displaceFactor);

    return layer.sample(sampled);
}
```

- [ ] **Step 3: Update Package.swift to bundle the .metal as a resource**

The Edit hook will block this — use the bypass marker:

```bash
echo 'AwaIroPlatform/Package\.swift$' > .claude/hooks/.bypass-next-edit
```

Now edit `packages/AwaIroPlatform/Package.swift` to add `resources: [.process("Effects")]` to the `.target`:

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AwaIroPlatform",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "AwaIroPlatform", targets: ["AwaIroPlatform"])
    ],
    dependencies: [
        .package(path: "../AwaIroDomain")
    ],
    targets: [
        .target(
            name: "AwaIroPlatform",
            dependencies: [
                .product(name: "AwaIroDomain", package: "AwaIroDomain")
            ],
            resources: [
                .process("Effects")
            ]
        ),
        .testTarget(name: "AwaIroPlatformTests", dependencies: ["AwaIroPlatform"])
    ]
)
```

- [ ] **Step 4: Implement the SwiftUI ViewModifier**

Create `packages/AwaIroPlatform/Sources/AwaIroPlatform/Effects/BubbleDistortion.swift`:

```swift
import SwiftUI

#if canImport(UIKit)
public extension View {
    /// Applies a sphere/bubble distortion to the receiving view, centered
    /// inside a circle of the given radius. Outside the circle, content
    /// passes through unchanged.
    func bubbleDistortion(radius: CGFloat, strength: Float = 0.4) -> some View {
        self
            .visualEffect { content, proxy in
                content.layerEffect(
                    ShaderLibrary.bundle(.module).bubbleDistortion(
                        .float2(proxy.size),
                        .float(Float(radius)),
                        .float(strength)
                    ),
                    maxSampleOffset: CGSize(width: radius, height: radius)
                )
            }
    }
}
#endif
```

- [ ] **Step 5: Verify build**

```bash
cd packages/AwaIroPlatform && swift build 2>&1 | tail -10
```

Expected: clean build (the `.metal` file gets compiled into the resource bundle; the SwiftUI helper is iOS-only).

- [ ] **Step 6: Commit**

```bash
cd /Users/nodayouta/Documents/code/AwaIro/.claude/worktrees/hardcore-mccarthy-b2a51f
git add packages/AwaIroPlatform/Package.swift packages/AwaIroPlatform/Sources/AwaIroPlatform/Effects/
git commit -m "$(cat <<'EOF'
feat(platform): add BubbleDistortion sphere shader (Metal + SwiftUI Shader API)

BubbleDistortion.metal: a [[ stitchable ]] half4 shader that takes a
SwiftUI Layer plus size/radius/strength uniforms and applies a barrel
distortion inside a circular region centered on the layer; outside the
circle, samples pass through unchanged.

BubbleDistortion.swift: SwiftUI ViewModifier .bubbleDistortion(radius:
strength:) that wraps the shader in a .layerEffect. iOS-only via
#if canImport(UIKit) so macOS builds skip it.

Package.swift: adds resources: [.process("Effects")] so SPM bundles
the .metal file. Bundle.module is used by ShaderLibrary at runtime.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 9: Platform — BubbleDistortion snapshot test

**Files:**
- Create: `packages/AwaIroPlatform/Tests/AwaIroPlatformTests/BubbleDistortionSnapshotTests.swift`

Snapshot the shader effect on a synthetic checkerboard-like image. Verifies the shader compiles, links, and produces a stable image.

- [ ] **Step 1: Write the test**

Create `packages/AwaIroPlatform/Tests/AwaIroPlatformTests/BubbleDistortionSnapshotTests.swift`:

```swift
#if canImport(UIKit)
import Testing
import SwiftUI
import SnapshotTesting
@testable import AwaIroPlatform

@Suite("BubbleDistortion snapshot")
@MainActor
struct BubbleDistortionSnapshotTests {

    /// A simple striped pattern that makes distortion visually obvious.
    private struct StripedView: View {
        var body: some View {
            ZStack {
                Color.black
                VStack(spacing: 0) {
                    ForEach(0..<10) { i in
                        Rectangle()
                            .fill(i.isMultiple(of: 2) ? .white : .gray)
                    }
                }
            }
            .frame(width: 300, height: 300)
        }
    }

    @Test("bubbleDistortion produces a stable rendering")
    func stableRendering() {
        let view = StripedView()
            .bubbleDistortion(radius: 120)
        let host = UIHostingController(rootView: view)
        host.view.frame = CGRect(x: 0, y: 0, width: 300, height: 300)
        assertSnapshot(of: host, as: .image(on: .iPhoneX(.portrait)))
    }
}
#endif
```

This test depends on swift-snapshot-testing which is currently a dep of AwaIroPresentation only. We need it on AwaIroPlatform's testTarget too.

- [ ] **Step 2: Add swift-snapshot-testing to AwaIroPlatform's testTarget [HITL]**

Use the bypass marker:

```bash
echo 'AwaIroPlatform/Package\.swift$' > .claude/hooks/.bypass-next-edit
```

Edit `packages/AwaIroPlatform/Package.swift` — add the snapshot dep alongside Domain:

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AwaIroPlatform",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "AwaIroPlatform", targets: ["AwaIroPlatform"])
    ],
    dependencies: [
        .package(path: "../AwaIroDomain"),
        .package(url: "https://github.com/pointfreeco/swift-snapshot-testing", from: "1.16.0")
    ],
    targets: [
        .target(
            name: "AwaIroPlatform",
            dependencies: [
                .product(name: "AwaIroDomain", package: "AwaIroDomain")
            ],
            resources: [
                .process("Effects")
            ]
        ),
        .testTarget(name: "AwaIroPlatformTests", dependencies: [
            "AwaIroPlatform",
            .product(name: "SnapshotTesting", package: "swift-snapshot-testing")
        ])
    ]
)
```

The user pre-approved snapshot-testing in Phase 1 (already test-only on Presentation). Adding it test-only on Platform is the same security profile per ADR 0004 — proceed without re-approval.

- [ ] **Step 3: Resolve and record snapshot**

```bash
cd packages/AwaIroPlatform && swift package resolve 2>&1 | tail -5
```

Then per ADR 0005 record cycle, add `record: .all` temporarily and run via xcodebuild:

```bash
cd packages/AwaIroPlatform && xcodebuild test \
  -scheme AwaIroPlatform \
  -destination 'platform=iOS Simulator,name=iPhone 16 (AwaIro)' \
  -only-testing:AwaIroPlatformTests/BubbleDistortionSnapshotTests \
  2>&1 | tail -20
```

Expect first run to fail with "snapshot recorded". Visually verify the recorded image (stripes warped inside a 240pt circle, unwarped outside). Then remove `record: .all` and re-run for verify.

- [ ] **Step 4: Commit (after verify pass)**

```bash
cd /Users/nodayouta/Documents/code/AwaIro/.claude/worktrees/hardcore-mccarthy-b2a51f
git add packages/AwaIroPlatform/Package.swift packages/AwaIroPlatform/Tests/AwaIroPlatformTests/BubbleDistortionSnapshotTests.swift packages/AwaIroPlatform/Tests/AwaIroPlatformTests/__Snapshots__/
git commit -m "$(cat <<'EOF'
test(platform): add BubbleDistortion snapshot on striped pattern

Renders a 10-band horizontal striped 300x300 view, applies
bubbleDistortion(radius: 120), and snapshots on iPhoneX(.portrait).
This verifies the .metal shader compiles, links, ships in the SPM
resource bundle, and produces a stable image.

Adds swift-snapshot-testing 1.x as a test-only dep of AwaIroPlatform
(same security profile as the existing Presentation test dep — both
pointfreeco/Apple-swiftlang-only chain per Phase 1 review).

Per ADR 0005 record cycle: snapshot recorded on iPhone 16 (AwaIro)
simulator, visually verified (warped stripes inside 240pt circle,
unwarped outside), record: .all flag removed, verify run green.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 10: Presentation — AppRoute enum

**Files:**
- Create: `packages/AwaIroPresentation/Sources/AwaIroPresentation/Navigation/AppRoute.swift`

Pure data type for `NavigationStack(path:)` routing. Hashable so it works as a `NavigationPath` element.

- [ ] **Step 1: Create directory**

```bash
mkdir -p packages/AwaIroPresentation/Sources/AwaIroPresentation/Navigation
```

- [ ] **Step 2: Implement**

Create `packages/AwaIroPresentation/Sources/AwaIroPresentation/Navigation/AppRoute.swift`:

```swift
import Foundation

public enum AppRoute: Hashable, Sendable {
    /// Captured photo, awaiting memo input and save.
    case memo(fileURL: URL, takenAt: Date)
}
```

Note: `home` is implicit (the root view); we only push to `memo` from there.

- [ ] **Step 3: Verify build**

```bash
cd packages/AwaIroPresentation && swift build 2>&1 | tail -3
```

Expected: clean build.

- [ ] **Step 4: Commit**

```bash
cd /Users/nodayouta/Documents/code/AwaIro/.claude/worktrees/hardcore-mccarthy-b2a51f
git add packages/AwaIroPresentation/Sources/AwaIroPresentation/Navigation/AppRoute.swift
git commit -m "$(cat <<'EOF'
feat(presentation): add AppRoute for NavigationStack path-based routing

Hashable Sendable enum. Single case .memo(fileURL:takenAt:) — Home is
implicit (root). NavigationStack(path:) consumes [AppRoute] to push
the MemoScreen after capture.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 11: Presentation — MemoViewModel

**Files:**
- Create: `packages/AwaIroPresentation/Sources/AwaIroPresentation/Memo/MemoViewModel.swift`
- Create: `packages/AwaIroPresentation/Tests/AwaIroPresentationTests/MemoViewModelTests.swift`

`@Observable @MainActor` ViewModel for MemoScreen. State machine:
- `.editing(memo: String)` — initial; user types
- `.saving` — save in progress
- `.saved(Photo)` — success terminal
- `.failed(message: String)` — error terminal (recoverable: user can retry or cancel)

Actions:
- `setMemo(_:)` — update text
- `save() async` — call RecordPhotoUseCase, then PhotoFileStore is left as-is (file already on disk from CameraController capture)
- `cancel() async` — call PhotoFileStore.delete(at:) to clean up the unsaved photo

Note: file cleanup on cancel/error is delegated to `MemoViewModel` via `cleanup`. Save success keeps the file (it's referenced by Photo).

- [ ] **Step 1: Create directory**

```bash
mkdir -p packages/AwaIroPresentation/Sources/AwaIroPresentation/Memo
```

- [ ] **Step 2: Write failing test**

Create `packages/AwaIroPresentation/Tests/AwaIroPresentationTests/MemoViewModelTests.swift`:

```swift
import Foundation
import Testing
import AwaIroDomain
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
        repo.alreadyHasToday = true // force G1 violation
        var cleanupCalls = 0
        let vm = MemoViewModel(
            fileURL: Self.url, takenAt: Self.takenAt,
            recordPhoto: RecordPhotoUseCase(repository: repo),
            cleanup: { _ in cleanupCalls += 1 }
        )
        await vm.save()
        if case .failed = vm.state {
            // ok
        } else {
            Issue.record("expected .failed, got \(vm.state)")
        }
        #expect(cleanupCalls == 0) // file kept; user may retry
    }

    @Test("cancel() invokes cleanup with file URL")
    @MainActor
    func cancelInvokesCleanup() async {
        var cleanupURL: URL?
        let vm = MemoViewModel(
            fileURL: Self.url, takenAt: Self.takenAt,
            recordPhoto: RecordPhotoUseCase(repository: FakeRepo()),
            cleanup: { url in cleanupURL = url }
        )
        await vm.cancel()
        #expect(cleanupURL == Self.url)
    }
}

private final class FakeRepo: PhotoRepository, @unchecked Sendable {
    var alreadyHasToday = false
    var inserted: [Photo] = []

    func todayPhoto(now: Date) async throws -> Photo? {
        if alreadyHasToday {
            return Photo(id: UUID(), takenAt: now, fileURL: URL(fileURLWithPath: "/tmp/old.jpg"), memo: nil)
        }
        return nil
    }

    func insert(_ photo: Photo) async throws {
        inserted.append(photo)
    }
}
```

- [ ] **Step 3: Verify FAIL**

```bash
cd packages/AwaIroPresentation && swift test --filter MemoViewModelTests 2>&1 | tail -10
```

Expected: FAIL — MemoViewModel not found.

- [ ] **Step 4: Implement**

Create `packages/AwaIroPresentation/Sources/AwaIroPresentation/Memo/MemoViewModel.swift`:

```swift
import Foundation
import AwaIroDomain

public enum MemoState: Equatable, Sendable {
    case editing(memo: String)
    case saving
    case saved(Photo)
    case failed(message: String)
}

@Observable
@MainActor
public final class MemoViewModel {
    public private(set) var state: MemoState = .editing(memo: "")

    public let fileURL: URL
    public let takenAt: Date
    private let recordPhoto: RecordPhotoUseCase
    private let cleanup: @Sendable (URL) async -> Void

    public init(
        fileURL: URL,
        takenAt: Date,
        recordPhoto: RecordPhotoUseCase,
        cleanup: @escaping @Sendable (URL) async -> Void
    ) {
        self.fileURL = fileURL
        self.takenAt = takenAt
        self.recordPhoto = recordPhoto
        self.cleanup = cleanup
    }

    public func setMemo(_ memo: String) {
        if case .editing = state {
            state = .editing(memo: memo)
        }
    }

    public func save() async {
        guard case .editing(let memo) = state else { return }
        state = .saving
        let memoOrNil: String? = memo.isEmpty ? nil : memo
        do {
            let photo = try await recordPhoto.execute(
                fileURL: fileURL,
                takenAt: takenAt,
                memo: memoOrNil
            )
            state = .saved(photo)
        } catch {
            state = .failed(message: String(describing: error))
        }
    }

    public func cancel() async {
        await cleanup(fileURL)
    }
}
```

- [ ] **Step 5: Verify PASS**

```bash
cd packages/AwaIroPresentation && swift test --filter MemoViewModelTests 2>&1 | tail -10
```

Expected: 6 tests passed.

- [ ] **Step 6: Commit**

```bash
cd /Users/nodayouta/Documents/code/AwaIro/.claude/worktrees/hardcore-mccarthy-b2a51f
git add packages/AwaIroPresentation/Sources/AwaIroPresentation/Memo/MemoViewModel.swift packages/AwaIroPresentation/Tests/AwaIroPresentationTests/MemoViewModelTests.swift
git commit -m "$(cat <<'EOF'
feat(presentation): add MemoViewModel with @Observable state machine

State transitions:
  .editing(memo) → setMemo → .editing(memo')
  .editing(memo) → save() → .saving → .saved(Photo) | .failed(message)
  any → cancel() → invokes cleanup(fileURL)

Empty memo string is normalized to nil before passing to RecordPhotoUseCase
(spec: empty memo is "no memo, allowed"). On save failure the file is NOT
auto-deleted; user can retry or explicitly cancel. Cleanup callback is
@Sendable so AppContainer can wire PhotoFileStore.delete(at:) into it.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 12: Presentation — MemoScreen view

**Files:**
- Create: `packages/AwaIroPresentation/Sources/AwaIroPresentation/Memo/MemoScreen.swift`

SwiftUI view: photo thumbnail at top, memo `TextField` below, "残す" / "やめる" buttons. Calls VM actions. On `.saved`, fires `onSaved()` callback so parent can pop nav.

- [ ] **Step 1: Implement**

Create `packages/AwaIroPresentation/Sources/AwaIroPresentation/Memo/MemoScreen.swift`:

```swift
import SwiftUI

public struct MemoScreen: View {
    @State private var viewModel: MemoViewModel
    private let onFinished: () -> Void

    public init(viewModel: MemoViewModel, onFinished: @escaping () -> Void) {
        _viewModel = State(initialValue: viewModel)
        self.onFinished = onFinished
    }

    public var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            content
        }
        .onChange(of: stateID) { _, newValue in
            // Auto-finish when state becomes .saved
            if case .saved = viewModel.state {
                onFinished()
            }
        }
    }

    /// Stable identifier so onChange fires on transitions.
    private var stateID: String {
        switch viewModel.state {
        case .editing: return "editing"
        case .saving: return "saving"
        case .saved: return "saved"
        case .failed: return "failed"
        }
    }

    @ViewBuilder
    private var content: some View {
        VStack(spacing: 24) {
            AsyncImage(url: viewModel.fileURL) { image in
                image
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 240, maxHeight: 240)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } placeholder: {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.white.opacity(0.1))
                    .frame(width: 240, height: 240)
                    .overlay(ProgressView().tint(.white))
            }

            switch viewModel.state {
            case .editing(let memo):
                memoField(initial: memo)
                actionButtons(canSave: true)

            case .saving:
                memoFieldDisabled()
                actionButtons(canSave: false)

            case .saved:
                Text("残しました")
                    .foregroundStyle(.white)

            case .failed(let message):
                memoFieldDisabled()
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.red.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                actionButtons(canSave: true) // user may retry
            }
        }
        .padding()
    }

    @ViewBuilder
    private func memoField(initial: String) -> some View {
        TextField("一言（任意）", text: Binding(
            get: { initial },
            set: { viewModel.setMemo($0) }
        ))
        .textFieldStyle(.roundedBorder)
        .foregroundStyle(.black)
        .padding(.horizontal)
        .accessibilityLabel("メモ入力")
    }

    @ViewBuilder
    private func memoFieldDisabled() -> some View {
        TextField("", text: .constant(""))
            .textFieldStyle(.roundedBorder)
            .disabled(true)
            .padding(.horizontal)
            .opacity(0.4)
    }

    @ViewBuilder
    private func actionButtons(canSave: Bool) -> some View {
        HStack(spacing: 16) {
            Button {
                Task {
                    await viewModel.cancel()
                    onFinished()
                }
            } label: {
                Text("やめる")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(.white)

            Button {
                Task { await viewModel.save() }
            } label: {
                Text("残す")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.white)
            .foregroundStyle(.black)
            .disabled(!canSave)
        }
        .padding(.horizontal)
    }
}
```

- [ ] **Step 2: Verify build**

```bash
cd packages/AwaIroPresentation && swift build 2>&1 | tail -3
```

Expected: clean build.

- [ ] **Step 3: Commit**

```bash
cd /Users/nodayouta/Documents/code/AwaIro/.claude/worktrees/hardcore-mccarthy-b2a51f
git add packages/AwaIroPresentation/Sources/AwaIroPresentation/Memo/MemoScreen.swift
git commit -m "$(cat <<'EOF'
feat(presentation): add MemoScreen view (photo + memo + save/cancel)

Black background, AsyncImage thumbnail (240pt rounded), TextField for
optional memo with placeholder "一言（任意）", and a two-button row
("やめる" → cancel + cleanup; "残す" → save). Visual states: editing
shows the editable field and active buttons; saving disables; saved
shows "残しました" before onFinished fires; failed shows the error and
keeps the field active so the user can retry.

stateID-based onChange auto-fires onFinished on .saved transition,
keeping the parent NavigationStack in charge of popping back to Home.

No numeric metrics anywhere (G3 preserved).

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 13: Presentation — BubbleCameraView (UIViewRepresentable + tap)

**Files:**
- Create: `packages/AwaIroPresentation/Sources/AwaIroPresentation/Home/BubbleCameraView.swift`

Wraps `AVCaptureVideoPreviewLayer` (from CameraController) in a `UIViewRepresentable`, applies `.bubbleDistortion(radius:)`, and exposes a tap gesture that calls `onCapture()`. Also handles preview lifecycle (start on appear, stop on disappear).

- [ ] **Step 1: Implement**

Create `packages/AwaIroPresentation/Sources/AwaIroPresentation/Home/BubbleCameraView.swift`:

```swift
#if canImport(UIKit) && canImport(AVFoundation)
import SwiftUI
import UIKit
import AVFoundation
import AwaIroPlatform

public struct BubbleCameraView: View {
    private let camera: any CameraController
    private let radius: CGFloat
    private let onTapCapture: @Sendable () async -> Void

    public init(
        camera: any CameraController,
        radius: CGFloat = 140,
        onTapCapture: @escaping @Sendable () async -> Void
    ) {
        self.camera = camera
        self.radius = radius
        self.onTapCapture = onTapCapture
    }

    public var body: some View {
        CameraPreviewRepresentable(camera: camera)
            .frame(width: radius * 2, height: radius * 2)
            .clipShape(Circle())
            .bubbleDistortion(radius: radius)
            .contentShape(Circle())
            .onTapGesture {
                Task { await onTapCapture() }
            }
            .task {
                do {
                    try await camera.start()
                } catch {
                    // Surface in console; HomeViewModel handles user-visible errors elsewhere
                    print("CameraController.start failed: \(error)")
                }
            }
            .onDisappear {
                Task { await camera.stop() }
            }
            .accessibilityLabel("泡をタップして撮影")
            .accessibilityAddTraits(.isButton)
    }
}

private struct CameraPreviewRepresentable: UIViewRepresentable {
    let camera: any CameraController

    @MainActor
    func makeUIView(context: Context) -> CameraPreviewUIView {
        let view = CameraPreviewUIView()
        view.previewLayer = camera.previewLayer
        return view
    }

    @MainActor
    func updateUIView(_ uiView: CameraPreviewUIView, context: Context) {
        uiView.previewLayer = camera.previewLayer
    }
}

@MainActor
private final class CameraPreviewUIView: UIView {
    var previewLayer: AVCaptureVideoPreviewLayer? {
        didSet {
            if let oldValue { oldValue.removeFromSuperlayer() }
            if let previewLayer {
                previewLayer.frame = bounds
                layer.addSublayer(previewLayer)
            }
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer?.frame = bounds
    }
}
#endif
```

- [ ] **Step 2: Verify build**

```bash
cd packages/AwaIroPresentation && swift build 2>&1 | tail -3
```

Expected: clean build (file is iOS-only via `#if canImport(UIKit) && canImport(AVFoundation)`).

- [ ] **Step 3: Commit**

```bash
cd /Users/nodayouta/Documents/code/AwaIro/.claude/worktrees/hardcore-mccarthy-b2a51f
git add packages/AwaIroPresentation/Sources/AwaIroPresentation/Home/BubbleCameraView.swift
git commit -m "$(cat <<'EOF'
feat(presentation): add BubbleCameraView (preview + distortion + tap)

UIViewRepresentable hosts AVCaptureVideoPreviewLayer (provided by
CameraController.previewLayer, MainActor-isolated). The host view is
clipped to a circle, then .bubbleDistortion(radius:) overlays the
sphere shader. contentShape(Circle()) restricts the tap region.

Lifecycle: .task starts the camera on appear, .onDisappear stops it.
Tap fires onTapCapture (async) — caller is HomeScreen which routes
to HomeViewModel.recordPhoto.

iOS-only via #if canImport(UIKit) && canImport(AVFoundation).

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 14: Presentation — extend HomeViewModel with capture flow

**Files:**
- Modify: `packages/AwaIroPresentation/Sources/AwaIroPresentation/Home/HomeViewModel.swift`
- Modify: `packages/AwaIroPresentation/Tests/AwaIroPresentationTests/HomeViewModelTests.swift`

Add to HomeViewModel:
- New init parameters: `cameraPermission: any CameraPermission`, `camera: any CameraController`, `photoFileStore: PhotoFileStore`
- New state field: `permission: CameraPermissionStatus`
- New action: `requestCameraIfNeeded() async`
- New action: `capturePhoto() async -> URL?` (calls camera.capture, writes via photoFileStore, returns URL for nav routing)

The router will react: if `capturePhoto` returns a non-nil URL, push `.memo(fileURL:takenAt:)` onto the navigation path.

- [ ] **Step 1: Add failing tests**

Append to `packages/AwaIroPresentation/Tests/AwaIroPresentationTests/HomeViewModelTests.swift` (inside the existing `HomeViewModelTests` suite):

```swift
    @Test("permission starts at .notDetermined")
    @MainActor
    func permissionInitial() {
        let vm = HomeViewModel(
            usecase: GetTodayPhotoUseCase(repository: StubRepo(value: nil)),
            cameraPermission: FakePermission(initial: .notDetermined),
            camera: FakeCamera(),
            photoFileStore: PhotoFileStore(filePathProvider: tempProvider())
        )
        #expect(vm.permission == .notDetermined)
    }

    @Test("requestCameraIfNeeded prompts when notDetermined and updates permission")
    @MainActor
    func requestPrompts() async {
        let perm = FakePermission(initial: .notDetermined, willGrant: true)
        let vm = HomeViewModel(
            usecase: GetTodayPhotoUseCase(repository: StubRepo(value: nil)),
            cameraPermission: perm,
            camera: FakeCamera(),
            photoFileStore: PhotoFileStore(filePathProvider: tempProvider())
        )
        await vm.requestCameraIfNeeded()
        #expect(vm.permission == .authorized)
        #expect(perm.requestCount == 1)
    }

    @Test("requestCameraIfNeeded does not re-prompt when already authorized")
    @MainActor
    func requestSkipsWhenAuthorized() async {
        let perm = FakePermission(initial: .authorized)
        let vm = HomeViewModel(
            usecase: GetTodayPhotoUseCase(repository: StubRepo(value: nil)),
            cameraPermission: perm,
            camera: FakeCamera(),
            photoFileStore: PhotoFileStore(filePathProvider: tempProvider())
        )
        await vm.requestCameraIfNeeded()
        #expect(perm.requestCount == 0)
        #expect(vm.permission == .authorized)
    }

    @Test("capturePhoto returns a URL after writing JPEG to file store")
    @MainActor
    func capturePhotoWritesFile() async throws {
        let camera = FakeCamera(captureData: Data([0xFF, 0xD8, 0xFF, 0xE0]))
        let provider = tempProvider()
        let store = PhotoFileStore(filePathProvider: provider)
        let vm = HomeViewModel(
            usecase: GetTodayPhotoUseCase(repository: StubRepo(value: nil)),
            cameraPermission: FakePermission(initial: .authorized),
            camera: camera,
            photoFileStore: store
        )
        let url = await vm.capturePhoto()
        let url2 = try #require(url)
        #expect(url2.path.hasPrefix(provider.photoDirectory.path))
        #expect(camera.captureCount == 1)
        let read = try Data(contentsOf: url2)
        #expect(read == Data([0xFF, 0xD8, 0xFF, 0xE0]))
    }
}

// Test helpers
import AwaIroPlatform

private func tempProvider() -> FilePathProvider {
    FilePathProvider(rootDirectory:
        FileManager.default.temporaryDirectory
            .appendingPathComponent("awairo-vm-test-\(UUID().uuidString)"))
}

private final class FakePermission: CameraPermission, @unchecked Sendable {
    private(set) var requestCount = 0
    private var status: CameraPermissionStatus
    private let willGrant: Bool

    init(initial: CameraPermissionStatus, willGrant: Bool = false) {
        self.status = initial
        self.willGrant = willGrant
    }

    func currentStatus() async -> CameraPermissionStatus {
        status
    }

    func requestIfNeeded() async -> CameraPermissionStatus {
        if status == .notDetermined {
            requestCount += 1
            status = willGrant ? .authorized : .denied
        }
        return status
    }
}

#if canImport(UIKit)
import UIKit
import AVFoundation

private final class FakeCamera: CameraController, @unchecked Sendable {
    private(set) var captureCount = 0
    var captureData: Data = Data()
    @MainActor lazy var previewLayer = AVCaptureVideoPreviewLayer()

    init(captureData: Data = Data([0xFF, 0xD8])) {
        self.captureData = captureData
    }

    func start() async throws {}
    func stop() async {}
    func capture() async throws -> Data {
        captureCount += 1
        return captureData
    }
}
#else
private final class FakeCamera: @unchecked Sendable {
    // Stub for macOS test build (HomeViewModel tests requiring camera live in #if canImport(UIKit))
}
#endif
```

Wait — these new tests reference `CameraController`, which is iOS-only. Wrap the new tests inside `#if canImport(UIKit)`. The existing `initialState` / `loadEmpty` / `loadPresent` / `loadError` tests should NOT depend on camera; they currently use the old initializer signature. We need to change them or keep them passing via convenience init.

Decision: introduce a convenience init that defaults camera-related parameters to harmless fakes for tests that don't care, OR update all existing tests with the new init.

Simplest: change all existing tests to pass `FakePermission(initial: .authorized) + FakeCamera() + tempProvider()`. The 4 existing tests need that update. Camera-touching tests are wrapped in `#if canImport(UIKit)`; the others run on macOS.

Actually since `CameraController` is `#if canImport(AVFoundation)` and AVFoundation is iOS-only-for-our-targets, `HomeViewModel` itself becomes iOS-only? That kills the macOS unit tests.

Resolution: HomeViewModel takes the camera dependency as `(any CameraController)?` (optional) so macOS swift-test can pass nil and test only the load/permission paths. Camera-dependent tests are iOS-only.

Better: HomeViewModel does NOT depend directly on CameraController at all. Camera operations are passed in as a closure: `capture: @Sendable () async throws -> Data`. This decouples the VM from AVFoundation entirely, making it testable on macOS. AppContainer wires in the actual camera at the call site.

Let me refactor the test + impl with this cleaner shape:

- HomeViewModel.init(...): adds `capturePhotoData: @Sendable () async throws -> Data` and `photoFileStore: PhotoFileStore`
- `capturePhoto()` uses the closure, writes via store, returns URL
- Permission can stay as protocol; that's iOS-only? No — protocol itself is Pure Swift; only the AVFoundation impl is gated. So it's safe on macOS.

OK rewrite the appended tests with this shape:

(see Step 2 below — this requires a revised version)

- [ ] **Step 2: Revised approach — use closures, not direct CameraController dep**

Keep tests cross-platform. Remove the `camera: any CameraController` parameter from HomeViewModel; instead add `capturePhotoData: @Sendable () async throws -> Data`.

Replace the appended test additions (Step 1 above) with this revised version:

```swift
    @Test("permission starts at .notDetermined")
    @MainActor
    func permissionInitial() {
        let vm = HomeViewModel(
            usecase: GetTodayPhotoUseCase(repository: StubRepo(value: nil)),
            cameraPermission: FakePermission(initial: .notDetermined),
            capturePhotoData: { Data() },
            photoFileStore: PhotoFileStore(filePathProvider: tempProvider())
        )
        #expect(vm.permission == .notDetermined)
    }

    @Test("requestCameraIfNeeded prompts when notDetermined and updates permission")
    @MainActor
    func requestPrompts() async {
        let perm = FakePermission(initial: .notDetermined, willGrant: true)
        let vm = HomeViewModel(
            usecase: GetTodayPhotoUseCase(repository: StubRepo(value: nil)),
            cameraPermission: perm,
            capturePhotoData: { Data() },
            photoFileStore: PhotoFileStore(filePathProvider: tempProvider())
        )
        await vm.requestCameraIfNeeded()
        #expect(vm.permission == .authorized)
        #expect(perm.requestCount == 1)
    }

    @Test("requestCameraIfNeeded does not re-prompt when already authorized")
    @MainActor
    func requestSkipsWhenAuthorized() async {
        let perm = FakePermission(initial: .authorized)
        let vm = HomeViewModel(
            usecase: GetTodayPhotoUseCase(repository: StubRepo(value: nil)),
            cameraPermission: perm,
            capturePhotoData: { Data() },
            photoFileStore: PhotoFileStore(filePathProvider: tempProvider())
        )
        await vm.requestCameraIfNeeded()
        #expect(perm.requestCount == 0)
        #expect(vm.permission == .authorized)
    }

    @Test("capturePhoto returns a URL after writing JPEG to file store")
    @MainActor
    func capturePhotoWritesFile() async throws {
        let captureData = Data([0xFF, 0xD8, 0xFF, 0xE0])
        let provider = tempProvider()
        let store = PhotoFileStore(filePathProvider: provider)
        let vm = HomeViewModel(
            usecase: GetTodayPhotoUseCase(repository: StubRepo(value: nil)),
            cameraPermission: FakePermission(initial: .authorized),
            capturePhotoData: { captureData },
            photoFileStore: store
        )
        let url = await vm.capturePhoto()
        let url2 = try #require(url)
        #expect(url2.path.hasPrefix(provider.photoDirectory.path))
        let read = try Data(contentsOf: url2)
        #expect(read == captureData)
    }
}

import AwaIroPlatform

private func tempProvider() -> FilePathProvider {
    FilePathProvider(rootDirectory:
        FileManager.default.temporaryDirectory
            .appendingPathComponent("awairo-vm-test-\(UUID().uuidString)"))
}

private final class FakePermission: CameraPermission, @unchecked Sendable {
    private(set) var requestCount = 0
    private var status: CameraPermissionStatus
    private let willGrant: Bool

    init(initial: CameraPermissionStatus, willGrant: Bool = false) {
        self.status = initial
        self.willGrant = willGrant
    }

    func currentStatus() async -> CameraPermissionStatus { status }

    func requestIfNeeded() async -> CameraPermissionStatus {
        if status == .notDetermined {
            requestCount += 1
            status = willGrant ? .authorized : .denied
        }
        return status
    }
}
```

Existing `HomeViewModelTests` (initialState / loadEmpty / loadPresent / loadError) need their VM constructions updated to pass the new params:

```swift
let vm = HomeViewModel(
    usecase: GetTodayPhotoUseCase(repository: StubRepo(value: nil)),
    cameraPermission: FakePermission(initial: .authorized),
    capturePhotoData: { Data() },
    photoFileStore: PhotoFileStore(filePathProvider: tempProvider())
)
```

Update each of the 4 existing test methods.

- [ ] **Step 3: Run to verify FAIL**

```bash
cd packages/AwaIroPresentation && swift test --filter HomeViewModelTests 2>&1 | tail -10
```

Expected: FAIL — HomeViewModel does not have the new init params or actions.

- [ ] **Step 4: Update HomeViewModel.swift**

Replace `packages/AwaIroPresentation/Sources/AwaIroPresentation/Home/HomeViewModel.swift`:

```swift
import Foundation
import AwaIroDomain
import AwaIroPlatform

public enum HomeState: Equatable, Sendable {
    case loading
    case unrecorded
    case recorded(Photo)
    case failed(String)
}

@Observable
@MainActor
public final class HomeViewModel {
    public private(set) var state: HomeState = .loading
    public private(set) var permission: CameraPermissionStatus = .notDetermined

    private let usecase: GetTodayPhotoUseCase
    private let cameraPermission: any CameraPermission
    private let capturePhotoData: @Sendable () async throws -> Data
    private let photoFileStore: PhotoFileStore

    public init(
        usecase: GetTodayPhotoUseCase,
        cameraPermission: any CameraPermission,
        capturePhotoData: @escaping @Sendable () async throws -> Data,
        photoFileStore: PhotoFileStore
    ) {
        self.usecase = usecase
        self.cameraPermission = cameraPermission
        self.capturePhotoData = capturePhotoData
        self.photoFileStore = photoFileStore
    }

    public func load(now: Date) async {
        state = .loading
        do {
            if let photo = try await usecase.execute(now: now) {
                state = .recorded(photo)
            } else {
                state = .unrecorded
            }
        } catch {
            state = .failed(String(describing: error))
        }
        permission = await cameraPermission.currentStatus()
    }

    public func requestCameraIfNeeded() async {
        permission = await cameraPermission.requestIfNeeded()
    }

    /// Captures a photo via the injected closure, writes the JPEG to disk,
    /// and returns the file URL. Returns nil on failure.
    public func capturePhoto() async -> URL? {
        do {
            let data = try await capturePhotoData()
            let id = UUID()
            let url = try photoFileStore.write(data: data, photoId: id)
            return url
        } catch {
            state = .failed(String(describing: error))
            return nil
        }
    }
}
```

- [ ] **Step 5: Verify PASS**

```bash
cd packages/AwaIroPresentation && swift test --filter HomeViewModelTests 2>&1 | tail -10
```

Expected: 8 tests passed (4 existing updated + 4 new).

- [ ] **Step 6: Commit**

```bash
cd /Users/nodayouta/Documents/code/AwaIro/.claude/worktrees/hardcore-mccarthy-b2a51f
git add packages/AwaIroPresentation/Sources/AwaIroPresentation/Home/HomeViewModel.swift packages/AwaIroPresentation/Tests/AwaIroPresentationTests/HomeViewModelTests.swift
git commit -m "$(cat <<'EOF'
feat(presentation): extend HomeViewModel with permission + capture flow

Adds:
- permission: CameraPermissionStatus, polled in load() and updated by
  requestCameraIfNeeded()
- capturePhoto() async -> URL? that invokes the injected
  capturePhotoData closure, writes the JPEG via PhotoFileStore, and
  returns the resulting file URL (or nil + .failed state on error)

Camera dep is a closure (not the CameraController type) so the VM stays
testable on macOS without #if canImport(AVFoundation). AppContainer
wires { try await camera.capture() } at construction.

Tests updated: 4 existing pass new init signature with stub deps; 4 new
cover initial permission, prompt-on-notDetermined, skip-when-authorized,
and capture-writes-file paths.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 15: Presentation — extend HomeContentView + HomeScreen for capture

**Files:**
- Modify: `packages/AwaIroPresentation/Sources/AwaIroPresentation/Home/HomeScreen.swift`

`HomeContentView` becomes parameterized so snapshot tests can inject a static placeholder for the bubble area instead of the live camera. `HomeScreen` (production) wraps `BubbleCameraView` when `.unrecorded + .authorized`, shows permission prompt UI when `.notDetermined`, and shows a denied UI when `.denied/.restricted`.

- [ ] **Step 1: Replace HomeScreen.swift**

```swift
import SwiftUI
import AwaIroDomain
import AwaIroPlatform

/// State-driven content view — parameterized over the bubble placeholder so
/// snapshot tests can inject a static stand-in instead of the live camera.
struct HomeContentView<Bubble: View>: View {
    let state: HomeState
    let permission: CameraPermissionStatus
    let bubble: () -> Bubble
    let onRequestPermission: () -> Void

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            content
        }
    }

    @ViewBuilder
    private var content: some View {
        switch state {
        case .loading:
            ProgressView()
                .tint(.white)
                .accessibilityLabel("読み込み中")

        case .unrecorded:
            switch permission {
            case .authorized:
                bubble()
            case .notDetermined:
                Button(action: onRequestPermission) {
                    Text("カメラへのアクセスを許可")
                        .padding()
                        .foregroundStyle(.white)
                }
                .buttonStyle(.bordered)
                .tint(.white)
                .accessibilityHint("カメラを使うには許可が要ります")
            case .denied, .restricted:
                VStack(spacing: 12) {
                    Text("カメラがオフになっています")
                        .foregroundStyle(.white)
                    Text("設定アプリからカメラを許可してください")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                }
            }

        case .recorded:
            Circle()
                .fill(.white.opacity(0.15))
                .frame(width: 200, height: 200)
                .accessibilityLabel("今日は記録しました")

        case .failed(let message):
            VStack(spacing: 12) {
                Text("読み込みに失敗しました")
                    .foregroundStyle(.white)
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
    }
}

#if canImport(UIKit) && canImport(AVFoundation)
import AVFoundation

/// Production HomeScreen — composes HomeContentView with a live BubbleCameraView.
public struct HomeScreen: View {
    @State private var viewModel: HomeViewModel
    private let camera: any CameraController
    private let onCaptured: (URL, Date) -> Void

    public init(
        viewModel: HomeViewModel,
        camera: any CameraController,
        onCaptured: @escaping (URL, Date) -> Void
    ) {
        _viewModel = State(initialValue: viewModel)
        self.camera = camera
        self.onCaptured = onCaptured
    }

    public var body: some View {
        HomeContentView(
            state: viewModel.state,
            permission: viewModel.permission,
            bubble: {
                BubbleCameraView(camera: camera) {
                    let takenAt = Date()
                    if let url = await viewModel.capturePhoto() {
                        onCaptured(url, takenAt)
                    }
                }
            },
            onRequestPermission: {
                Task { await viewModel.requestCameraIfNeeded() }
            }
        )
        .task {
            await viewModel.load(now: Date())
        }
    }
}
#endif

#if DEBUG
#Preview("unrecorded + authorized (placeholder bubble)") {
    HomeContentView(
        state: .unrecorded,
        permission: .authorized,
        bubble: { Circle().fill(.white.opacity(0.85)).frame(width: 280, height: 280) },
        onRequestPermission: {}
    )
}

#Preview("notDetermined") {
    HomeContentView(
        state: .unrecorded,
        permission: .notDetermined,
        bubble: { EmptyView() },
        onRequestPermission: {}
    )
}

#Preview("denied") {
    HomeContentView(
        state: .unrecorded,
        permission: .denied,
        bubble: { EmptyView() },
        onRequestPermission: {}
    )
}

#Preview("recorded") {
    HomeContentView(
        state: .recorded(Photo(
            id: UUID(),
            takenAt: Date(),
            fileURL: URL(fileURLWithPath: "/tmp/preview.jpg"),
            memo: "preview"
        )),
        permission: .authorized,
        bubble: { EmptyView() },
        onRequestPermission: {}
    )
}
#endif
```

- [ ] **Step 2: Update HomeScreenSnapshotTests for the new HomeContentView signature**

Edit `packages/AwaIroPresentation/Tests/AwaIroPresentationTests/HomeScreenSnapshotTests.swift` — the existing 3 tests use the old `HomeContentView(state:)` API. Update them:

```swift
#if canImport(UIKit)
import Testing
import UIKit
import SwiftUI
import SnapshotTesting
@testable import AwaIroPresentation

@Suite("HomeScreen snapshot — G3 guardrail")
@MainActor
struct HomeScreenSnapshotTests {

    private let prohibitedWords: [String] = [
        "いいね", "Like", "Likes",
        "フォロワー", "Follower", "Followers",
        "閲覧", "Views", "View count",
        "シェア数", "Shares"
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
            state: .recorded(Photo(
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
            state: .recorded(Photo(
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
            #expect(!allText.contains(word),
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
```

The existing 2 snapshot images (`unrecordedSnapshot.1.png`, `recordedSnapshot.1.png`) will be obsolete. New snapshots: `unrecordedAuthorizedSnapshot.1.png`, `unrecordedNotDeterminedSnapshot.1.png`, `unrecordedDeniedSnapshot.1.png`, `recordedSnapshot.1.png`.

- [ ] **Step 3: Re-record snapshots per ADR 0005**

Delete obsolete snapshots, add `record: .all` (or wrap with `withSnapshotTesting(record: .all) { ... }`), run xcodebuild test, visually verify, remove record flag, re-run for verify:

```bash
rm -rf packages/AwaIroPresentation/Tests/AwaIroPresentationTests/__Snapshots__/HomeScreenSnapshotTests/
```

Then per ADR 0005, modify the test temporarily to record (e.g., `withSnapshotTesting(record: .all) { ... }` around the body of each `@Test`), run:

```bash
cd packages/AwaIroPresentation && xcodebuild test \
  -scheme AwaIroPresentation \
  -destination 'platform=iOS Simulator,name=iPhone 16 (AwaIro)' \
  -only-testing:AwaIroPresentationTests/HomeScreenSnapshotTests \
  2>&1 | tail -10
```

Visually inspect the 4 new images. Then remove the record flag and re-run; expect TEST SUCCEEDED.

- [ ] **Step 4: Verify build (macOS — HomeContentView is iOS+macOS, HomeScreen production is iOS-only)**

```bash
cd packages/AwaIroPresentation && swift build 2>&1 | tail -3
```

Expected: clean build. macOS swift test only sees HomeContentView (in PreviewHelpers + HomeViewModelTests); HomeScreen production class is gated.

- [ ] **Step 5: Verify tests on macOS**

```bash
cd packages/AwaIroPresentation && swift test 2>&1 | tail -10
```

Expected: 8 (HomeViewModel) + 6 (MemoViewModel) = 14 tests passed. Snapshot tests skip on macOS (#if canImport(UIKit)).

- [ ] **Step 6: Commit**

```bash
cd /Users/nodayouta/Documents/code/AwaIro/.claude/worktrees/hardcore-mccarthy-b2a51f
git add packages/AwaIroPresentation/Sources/AwaIroPresentation/Home/HomeScreen.swift packages/AwaIroPresentation/Tests/AwaIroPresentationTests/HomeScreenSnapshotTests.swift packages/AwaIroPresentation/Tests/AwaIroPresentationTests/__Snapshots__/
git commit -m "$(cat <<'EOF'
feat(presentation): integrate BubbleCameraView and permission UI in HomeScreen

HomeContentView now parameterizes over the bubble area with a generic
View provider — snapshot tests inject a static placeholder, production
injects a live BubbleCameraView. Permission UI:
- .authorized → bubble visible
- .notDetermined → "カメラへのアクセスを許可" button (calls
  HomeViewModel.requestCameraIfNeeded)
- .denied/.restricted → instructive text pointing to Settings.app

HomeScreen (production, iOS-only) gains camera + onCaptured callback
parameters; on tap → capturePhoto via HomeViewModel → callback fires
with (URL, Date) so the parent NavigationStack can push to MemoScreen.

Snapshot tests expanded from 2 to 4 (added notDetermined and denied
states). Snapshots re-recorded on iPhone 16 (AwaIro), visually verified
per ADR 0005.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 16: App — extend AppContainer with camera + capture wiring

**Files:**
- Modify: `App/AwaIro/AppContainer.swift`

Adds camera deps and a factory for MemoViewModel.

- [ ] **Step 1: Replace AppContainer.swift**

```swift
import Foundation
import AwaIroDomain
import AwaIroData
import AwaIroPlatform
import AwaIroPresentation
import AVFoundation

@MainActor
final class AppContainer {
    let filePathProvider: FilePathProvider
    let photoRepository: any PhotoRepository
    let getTodayPhotoUseCase: GetTodayPhotoUseCase
    let recordPhotoUseCase: RecordPhotoUseCase
    let cameraPermission: any CameraPermission
    let camera: any CameraController
    let photoFileStore: PhotoFileStore

    init() throws {
        let provider = try FilePathProvider.defaultProduction()
        self.filePathProvider = provider

        let pool = try DatabaseFactory.makePool(at: provider.databaseURL)
        let repo = PhotoRepositoryImpl(writer: pool)
        self.photoRepository = repo

        self.getTodayPhotoUseCase = GetTodayPhotoUseCase(repository: repo)
        self.recordPhotoUseCase = RecordPhotoUseCase(repository: repo)
        self.cameraPermission = AVFoundationCameraPermission()
        self.camera = AVFoundationCameraController()
        self.photoFileStore = PhotoFileStore(filePathProvider: provider)
    }

    func makeHomeViewModel() -> HomeViewModel {
        let cameraRef = camera
        return HomeViewModel(
            usecase: getTodayPhotoUseCase,
            cameraPermission: cameraPermission,
            capturePhotoData: { try await cameraRef.capture() },
            photoFileStore: photoFileStore
        )
    }

    func makeMemoViewModel(fileURL: URL, takenAt: Date) -> MemoViewModel {
        let storeRef = photoFileStore
        return MemoViewModel(
            fileURL: fileURL,
            takenAt: takenAt,
            recordPhoto: recordPhotoUseCase,
            cleanup: { url in
                try? storeRef.delete(at: url)
            }
        )
    }
}
```

- [ ] **Step 2: Verify App builds**

```bash
xcodebuild build \
  -project App/AwaIro.xcodeproj \
  -scheme AwaIro \
  -destination 'platform=iOS Simulator,name=iPhone 16 (AwaIro)' \
  -quiet 2>&1 | tail -5
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
cd /Users/nodayouta/Documents/code/AwaIro/.claude/worktrees/hardcore-mccarthy-b2a51f
git add App/AwaIro/AppContainer.swift
git commit -m "$(cat <<'EOF'
feat(app): extend AppContainer with camera + RecordPhoto + MemoVM factory

Adds: recordPhotoUseCase, cameraPermission (AVFoundation impl),
camera (AVFoundationCameraController), photoFileStore.

Factories:
- makeHomeViewModel() wraps camera.capture in the closure HomeViewModel
  expects (capturePhotoData), keeping the VM testable without AVFoundation
- makeMemoViewModel(fileURL:takenAt:) wires PhotoFileStore.delete into
  the cleanup callback for cancel/discard

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 17: App — Info.plist NSCameraUsageDescription [HITL bypass marker]

**Files:**
- Modify: `App/AwaIro.xcodeproj/project.pbxproj` (add INFOPLIST_KEY_NSCameraUsageDescription build setting)

We use Xcode's "GENERATE_INFOPLIST_FILE = YES" build setting (which the project uses) — adding the camera permission description is done by adding `INFOPLIST_KEY_NSCameraUsageDescription` to both Debug and Release build configurations of the AwaIro target. This avoids creating an explicit Info.plist file.

- [ ] **Step 1: Set the bypass marker (project.pbxproj is sensitive)**

```bash
echo 'AwaIro\.xcodeproj/project\.pbxproj$' > .claude/hooks/.bypass-next-edit
```

- [ ] **Step 2: Edit project.pbxproj**

Find the two AwaIro-target build configurations (Debug `A100000100000000000000F0` and Release `A100000100000000000000F1`). In each `buildSettings = { ... }` block, **add this line** after `INFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents = YES;`:

```
				INFOPLIST_KEY_NSCameraUsageDescription = "泡を通して今日の1枚を撮影します";
```

The marker only allows ONE edit; if you make a typo, write the marker again.

The Edit tool will trigger the gate; the marker bypasses for one edit. After the edit, the marker is auto-consumed.

- [ ] **Step 3: Verify build**

```bash
xcodebuild build \
  -project App/AwaIro.xcodeproj \
  -scheme AwaIro \
  -destination 'platform=iOS Simulator,name=iPhone 16 (AwaIro)' \
  -quiet 2>&1 | tail -5
```

Expected: BUILD SUCCEEDED. The generated Info.plist now has `NSCameraUsageDescription`.

- [ ] **Step 4: Verify Info.plist key surfaced (G4 guardrail check)**

```bash
APP=$(find ~/Library/Developer/Xcode/DerivedData -name 'AwaIro.app' -type d | head -1)
plutil -p "$APP/Info.plist" | grep -E 'Camera|aps-environment|UIBackgroundModes|remote-notification'
```

Expected:
- `"NSCameraUsageDescription" => "泡を通して今日の1枚を撮影します"`
- NO `aps-environment`
- NO `UIBackgroundModes => remote-notification`

If push entitlements appear, the build accidentally added them — STOP and investigate before committing.

- [ ] **Step 5: Commit**

```bash
cd /Users/nodayouta/Documents/code/AwaIro/.claude/worktrees/hardcore-mccarthy-b2a51f
git add App/AwaIro.xcodeproj/project.pbxproj
git commit -m "$(cat <<'EOF'
feat(app): add NSCameraUsageDescription via GENERATE_INFOPLIST_FILE setting

Adds INFOPLIST_KEY_NSCameraUsageDescription build setting to AwaIro
target's Debug and Release configurations: "泡を通して今日の1枚を撮影します".
This surfaces in the auto-generated Info.plist on build, satisfying
iOS's mandatory privacy-string requirement for AVCaptureDevice access.

Concept Guardrail G4 verified post-build via plutil:
- NSCameraUsageDescription present
- aps-environment NOT present
- UIBackgroundModes does NOT contain remote-notification

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 18: App — wire NavigationStack with AppRoute in RootContentView + AwaIroApp

**Files:**
- Modify: `App/AwaIro/RootContentView.swift`
- Modify: `App/AwaIro/AwaIroApp.swift` (no change actually — keep as-is)

Path-based NavigationStack in `RootContentView`. HomeScreen `onCaptured` appends to path; MemoScreen `onFinished` removes from path (popping back to Home, which re-loads photo state).

- [ ] **Step 1: Replace RootContentView.swift**

```swift
import SwiftUI
import AwaIroPresentation

struct RootContentView: View {
    let container: AppContainer
    @State private var path: [AppRoute] = []

    var body: some View {
        NavigationStack(path: $path) {
            HomeScreen(
                viewModel: container.makeHomeViewModel(),
                camera: container.camera,
                onCaptured: { url, takenAt in
                    path.append(.memo(fileURL: url, takenAt: takenAt))
                }
            )
            .navigationBarHidden(true)
            .navigationDestination(for: AppRoute.self) { route in
                switch route {
                case .memo(let fileURL, let takenAt):
                    MemoScreen(
                        viewModel: container.makeMemoViewModel(fileURL: fileURL, takenAt: takenAt),
                        onFinished: {
                            path.removeAll()
                        }
                    )
                    .navigationBarHidden(true)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
```

`AwaIroApp.swift` does NOT need changes — it still constructs AppContainer and passes it to RootContentView.

- [ ] **Step 2: Build for Simulator**

```bash
xcodebuild build \
  -project App/AwaIro.xcodeproj \
  -scheme AwaIro \
  -destination 'platform=iOS Simulator,name=iPhone 16 (AwaIro)' \
  -quiet 2>&1 | tail -5
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Run smoke test**

```bash
make test-app-smoke 2>&1 | tail -10
```

Expected: ✅ App smoke test passed.

- [ ] **Step 4: Commit**

```bash
cd /Users/nodayouta/Documents/code/AwaIro/.claude/worktrees/hardcore-mccarthy-b2a51f
git add App/AwaIro/RootContentView.swift
git commit -m "$(cat <<'EOF'
feat(app): NavigationStack(path:) with AppRoute for Home → Memo flow

RootContentView now hosts a NavigationStack with [AppRoute] state.
HomeScreen.onCaptured appends .memo(fileURL:takenAt:); the
.navigationDestination handler resolves it to MemoScreen built from
AppContainer.makeMemoViewModel. MemoScreen.onFinished clears the path,
popping back to HomeScreen which re-triggers .task and re-loads the
recorded state from the DB.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 19: Presentation — MemoScreen snapshot test

**Files:**
- Create: `packages/AwaIroPresentation/Tests/AwaIroPresentationTests/MemoScreenSnapshotTests.swift`

Snapshot the editing / saving / failed states. AsyncImage with a missing URL renders the placeholder, which is a stable (not network-dependent) baseline.

- [ ] **Step 1: Write the test**

Create `packages/AwaIroPresentation/Tests/AwaIroPresentationTests/MemoScreenSnapshotTests.swift`:

```swift
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
        "シェア数", "Shares"
    ]

    private func makeVM(state: MemoState = .editing(memo: "")) -> MemoViewModel {
        let vm = MemoViewModel(
            fileURL: URL(fileURLWithPath: "/tmp/missing-on-purpose.jpg"),
            takenAt: Date(),
            recordPhoto: RecordPhotoUseCase(repository: NoOpRepo()),
            cleanup: { _ in }
        )
        // Force the desired state via reflection-free path:
        switch state {
        case .editing(let memo): vm.setMemo(memo)
        case .saving, .saved, .failed: break // require post-action; covered separately
        }
        return vm
    }

    @Test("editing snapshot is stable")
    func editingSnapshot() {
        let host = UIHostingController(rootView: MemoScreen(viewModel: makeVM(state: .editing(memo: "morning")), onFinished: {}))
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
```

- [ ] **Step 2: Record + verify snapshots per ADR 0005**

```bash
cd packages/AwaIroPresentation && xcodebuild test \
  -scheme AwaIroPresentation \
  -destination 'platform=iOS Simulator,name=iPhone 16 (AwaIro)' \
  -only-testing:AwaIroPresentationTests/MemoScreenSnapshotTests \
  2>&1 | tail -15
```

(Add `record: .all` temporarily on first run; remove after verifying.)

Expected after verify: 2 tests passed.

- [ ] **Step 3: Commit**

```bash
cd /Users/nodayouta/Documents/code/AwaIro/.claude/worktrees/hardcore-mccarthy-b2a51f
git add packages/AwaIroPresentation/Tests/AwaIroPresentationTests/MemoScreenSnapshotTests.swift packages/AwaIroPresentation/Tests/AwaIroPresentationTests/__Snapshots__/MemoScreenSnapshotTests/
git commit -m "$(cat <<'EOF'
test(presentation): add MemoScreen snapshot + G3 guardrail

editingSnapshot baselines the .editing state on iPhoneX(.portrait);
the AsyncImage falls through to placeholder for the missing-on-purpose
URL, giving a stable visual without depending on disk content.

noNumericMetrics walks the rendered view tree and asserts none of the
prohibited "他者評価" strings appear, mirroring the HomeScreen G3 test.

Snapshots recorded and visually verified on iPhone 16 (AwaIro) per
ADR 0005.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 20: Verification — full make verify + manual record-flow on Simulator

- [ ] **Step 1: Run full make verify**

```bash
make verify 2>&1 | tail -10
```

Expected: ✅ make verify passed (build + macOS test + iOS snapshot tests + smoke + lint).

- [ ] **Step 2: Manual flow verification on Simulator**

```bash
xcrun simctl boot "iPhone 16 (AwaIro)" 2>/dev/null || true
open -a Simulator
sleep 3
xcodebuild build -project App/AwaIro.xcodeproj -scheme AwaIro \
  -destination 'platform=iOS Simulator,name=iPhone 16 (AwaIro)' \
  -derivedDataPath build/ -quiet 2>&1 | tail -3
APP_PATH=$(find build/Build/Products -name "AwaIro.app" -type d | head -1)
xcrun simctl install booted "$APP_PATH"
xcrun simctl launch booted io.awairo.AwaIro
```

Manually in the Simulator:

1. App launches → permission prompt (Simulator returns .authorized without UI; if it shows a dialog, tap Allow)
2. HomeScreen shows the bubble (Simulator camera = black/test pattern, distortion still applies inside the circle)
3. Tap the bubble → MemoScreen pushes
4. MemoScreen shows the placeholder (real image not visible because Simulator has no actual camera frame; that's expected)
5. Tap "残す" with empty memo → returns to HomeScreen
6. HomeScreen now shows the "recorded" state (gray circle)
7. Force-quit and re-launch → HomeScreen still shows recorded state (DB persisted)
8. (Optional) Wait until next day or set Simulator date to next day; HomeScreen returns to unrecorded state

If anything misbehaves at steps 1-7 → STOP and debug. Step 8 is informational.

- [ ] **Step 3: Take screenshots of the new states**

```bash
mkdir -p docs/snapshots/phase-2
xcrun simctl io booted screenshot "$PWD/docs/snapshots/phase-2/home-bubble-iphone16.png"
# After tapping, before save:
xcrun simctl io booted screenshot "$PWD/docs/snapshots/phase-2/memo-editing-iphone16.png"
# After save, back on Home:
xcrun simctl io booted screenshot "$PWD/docs/snapshots/phase-2/home-recorded-iphone16.png"
```

(You'll need to take each screenshot at the appropriate moment during manual testing.)

- [ ] **Step 4: Commit screenshots**

```bash
cd /Users/nodayouta/Documents/code/AwaIro/.claude/worktrees/hardcore-mccarthy-b2a51f
git add docs/snapshots/phase-2/
git commit -m "$(cat <<'EOF'
docs(snapshot): capture Phase 2 record flow on iPhone 16 (AwaIro)

Three artifacts of the live record flow:
- home-bubble-iphone16.png: HomeScreen with active BubbleCameraView
- memo-editing-iphone16.png: MemoScreen mid-edit
- home-recorded-iphone16.png: HomeScreen post-save (gray circle)

Captured manually after tap-to-record on the Simulator. Simulator
camera renders a black/test-pattern frame which is expected behavior
without real hardware; the shader and capture path are still
exercised end-to-end.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 21: Phase 2 retro template + README update

**Files:**
- Create: `docs/harness/phase2-retro.md`
- Modify: `README.md`

- [ ] **Step 1: Write retro template**

Create `docs/harness/phase2-retro.md`:

```markdown
# Phase 2 Retro — Sprint 1 Record

**Date:** <YYYY-MM-DD>
**Participants:** nusnody, Orchestrator
**Phase 2 plan:** [2026-05-04-phase-2-record.md](../superpowers/plans/2026-05-04-phase-2-record.md)
**Phase 2 commit range:** <fill at close>

> Phase 2 完了直後に埋める。Phase 0/1 retro と同じ書式。

## What worked

- (例) BubbleDistortion の SwiftUI Shader API が想定より素直に動いた
- (例) HomeViewModel の camera dep を closure 化したことで macOS テストを保てた
- ...

## What didn't (friction points)

- (例) Simulator のカメラが黒画面で UX 確認が手薄
- (例) Info.plist の build setting 経由設定で初学者が迷う
- ...

## Trust Ladder decisions

| 操作 | Phase 2 末の判断 | 根拠 |
|------|--------------|------|
| ... | ... | ... |

## Plan deviations

| Task | 計画 | 実装 | 理由 |
|------|------|------|------|
| ... | ... | ... | ... |

## Spec / ADR updates needed

- ...

## Phase 3 entry blockers

- ...

## Process improvements for Phase 3

- ...

## References

- Phase 0 retro / Phase 1 retro
- Phase 2 plan
- ADR 0005
- Phase 2 screenshots
```

- [ ] **Step 2: Update README sprint table**

```bash
# Edit README.md and update:
# | Conversion Phase 2 | Sprint 1 (記録) port | 🔨 次フェーズ |
# to:
# | Conversion Phase 2 | Sprint 1 (記録) port | ✅ 完了 |
# | Conversion Phase 3 | Sprint 2 (現像) ネイティブ実装 | 🔨 次フェーズ |
```

Use Edit tool to make this change.

- [ ] **Step 3: Commit**

```bash
cd /Users/nodayouta/Documents/code/AwaIro/.claude/worktrees/hardcore-mccarthy-b2a51f
git add docs/harness/phase2-retro.md README.md
git commit -m "$(cat <<'EOF'
docs: add Phase 2 retro template + mark Phase 2 complete in README

Retro template to be filled at Phase 2 close-out (what worked, friction
points, Trust Ladder decisions, plan deviations, ADR updates needed,
Phase 3 entry blockers).

README sprint table: Phase 2 → ✅ 完了, Phase 3 → 🔨 次フェーズ.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Self-Review

**Spec coverage check** (Sprint 1 spec sections vs Phase 2 plan tasks):

| Spec requirement | Plan task |
|------------------|-----------|
| Photo capture UX (tap bubble) | Tasks 13 (BubbleCameraView tap) + 14 (capturePhoto action) |
| Bubble + camera preview + distortion | Tasks 7 (CameraController) + 8 (BubbleDistortion) + 13 (BubbleCameraView) |
| 1日1枚 enforcement (G1) | Task 2 (RecordPhotoUseCase + 5 tests) |
| MemoScreen with optional memo | Task 11 (MemoViewModel) + 12 (MemoScreen) |
| Save → Home transitions | Task 18 (NavigationStack(path:) routing) |
| Cancel cleanup (delete file) | Task 11 (MemoViewModel.cancel + cleanup callback) + 16 (AppContainer wiring) |
| Camera permission flow | Tasks 5 (Status) + 6 (Permission protocol/impl) + 14 (HomeViewModel.requestCameraIfNeeded) + 15 (HomeContentView UI) |
| Persistence | Tasks 14 (PhotoFileStore.write) + 11 (MemoViewModel.save → RecordPhotoUseCase → PhotoRepositoryImpl) |
| Same-day re-launch shows gray bubble | Task 18 (path.removeAll → HomeScreen .task → load) |
| Concept Guardrails G3 (no numbers) | Tasks 15 (HomeContentView) + 19 (MemoScreen) snapshot tests with prohibitedWords |
| Concept Guardrail G4 (no push) | Task 17 plutil verification step |
| iOS-only stack (Phase 0/1 stack continuation) | All tasks use SwiftUI / @Observable / Swift Concurrency / Swift Testing |

**Placeholder scan:** No "TBD" / "TODO" / "fill in details" outside intentional retro template content (Task 21 retro doc is a template by design).

**Type / signature consistency:**
- `RecordPhotoUseCase.execute(fileURL:takenAt:memo:)` — same signature in Tasks 2, 11, 16
- `RecordPhotoError` cases — `.alreadyRecordedToday` / `.repositoryFailure(message:)` consistent across Tasks 1, 2, 11
- `CameraPermissionStatus` cases — `.notDetermined / .authorized / .denied / .restricted` consistent across Tasks 5, 6, 14, 15
- `CameraController` protocol — `start / stop / capture / previewLayer` consistent across Tasks 7, 13, 16
- `MemoState` cases — `.editing / .saving / .saved / .failed` consistent across Tasks 11, 12, 19
- `AppRoute.memo(fileURL:takenAt:)` — consistent in Tasks 10, 18
- `HomeViewModel.init` extended signature — Tasks 14, 16 match
- `PhotoFileStore.write(data:photoId:)` and `delete(at:)` — Tasks 4, 11, 14, 16 match

**Corrections made during self-review:**
1. Task 14 originally specified `camera: any CameraController` direct dep on HomeViewModel, which would force iOS-only compilation. Refactored to a `capturePhotoData: @Sendable () async throws -> Data` closure so the VM stays testable on macOS. Updated Step 1 / 2 / 4 of Task 14 accordingly.
2. Task 15's HomeContentView became generic over Bubble: View so snapshot tests can inject placeholders. Existing snapshot tests need updating (Step 2).
3. Task 17 reverted from "edit Info.plist directly" to "set INFOPLIST_KEY_NSCameraUsageDescription build setting" because the project uses GENERATE_INFOPLIST_FILE = YES — there is no Info.plist file to edit.

---

## Notes for Executor

1. **HITL marker file usage** (Tasks 8 Step 3, Task 9 Step 2, Task 17 Step 1): write the regex pattern to `.claude/hooks/.bypass-next-edit` IMMEDIATELY before the corresponding Edit tool call. The marker is consumed on read (one-shot). If you forget, the edit-gate will block and you'll need to write the marker again.

2. **Snapshot record cycle** (Tasks 9, 15, 19) per ADR 0005: add `record: .all` (or wrap test body with `withSnapshotTesting(record: .all) { ... }`) → run xcodebuild test → eyeball PNGs in `__Snapshots__/` → remove the record flag → re-run for verify pass.

3. **Manual Simulator testing** (Task 20) requires a real human to interact. Subagent dispatch can't drive Simulator UI directly; the orchestrator should handoff to the user for Step 2 of Task 20.

4. **Camera on Simulator**: AVCaptureDevice.default(.builtInWideAngleCamera, ...) returns nil on iOS Simulator on some Xcode versions. If you see `CameraControllerError.noBackCamera`, that's expected on Simulator; the BubbleCameraView falls through to a black preview circle. Real camera is verified on device only (out of Phase 2 scope; Phase 3 retro can decide if device CI is needed).

5. **Phase 2 should yield ~20 commits**. Each is small and reversible. Push at end via `HITL_BYPASS=1 git push origin <branch>` to a new feature branch (likely `conversion/phase-2-record`).
