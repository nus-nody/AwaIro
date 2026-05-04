# Phase 1 Walking Skeleton Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Domain → Data → Platform → Presentation → App の縦串を最小限通し、iOS Simulator で `HomeScreen` が「今日撮影済 / 未撮影」状態に応じて描画されることを確認する。Camera/Memo は Phase 2、Develop は Phase 3。

**Architecture:** SPM 4 パッケージは Phase 0 で構築済み。Phase 1 で各パッケージに最小限の Domain 型・GRDB 永続化・SwiftUI View・@Observable ViewModel を追加し、新規 Xcode App Target を Composition Root として束ねる。`make verify` 緑 + `make test-ios`（新設）緑 + Simulator 動作確認が DoD。

**Tech Stack:** Swift 6 / GRDB.swift 7.x / swift-snapshot-testing 1.x / Swift Testing / SwiftUI + @Observable / Xcode 26

**Spec:** [2026-05-04-kmp-to-ios-conversion-design.md § Phase 1](../specs/2026-05-04-kmp-to-ios-conversion-design.md)

---

## File Structure

### Created in this Phase

```
packages/
├── AwaIroDomain/
│   └── Sources/AwaIroDomain/
│       ├── Models/Photo.swift                      # value type
│       ├── Repositories/PhotoRepository.swift      # protocol
│       └── UseCases/GetTodayPhotoUseCase.swift
│   └── Tests/AwaIroDomainTests/
│       └── GetTodayPhotoUseCaseTests.swift
├── AwaIroData/
│   └── Sources/AwaIroData/
│       ├── Database/DatabaseFactory.swift          # GRDB DatabasePool factory
│       ├── Database/Migrations.swift               # v1: photos table
│       └── Repositories/PhotoRepositoryImpl.swift  # GRDB-backed
│   └── Tests/AwaIroDataTests/
│       └── PhotoRepositoryImplTests.swift          # in-memory GRDB
├── AwaIroPlatform/
│   └── Sources/AwaIroPlatform/
│       └── Files/FilePathProvider.swift
│   └── Tests/AwaIroPlatformTests/
│       └── FilePathProviderTests.swift
└── AwaIroPresentation/
    └── Sources/AwaIroPresentation/
        ├── Home/HomeScreen.swift                   # SwiftUI view
        └── Home/HomeViewModel.swift                # @Observable
    └── Tests/AwaIroPresentationTests/
        ├── HomeViewModelTests.swift                # mock repository
        └── HomeScreenSnapshotTests.swift           # G3 guardrail (iOS only)

App/                                                # NEW — Xcode App Target
├── AwaIro.xcodeproj/
├── AwaIro/
│   ├── AwaIroApp.swift                             # @main
│   ├── RootContentView.swift                       # NavigationStack root
│   ├── AppContainer.swift                          # Composition Root
│   └── Info.plist                                  # blank (NO push, NO mic yet)
└── AwaIroTests/
    └── (intentionally empty — package tests run via xcodebuild)
```

### Modified in this Phase

```
packages/AwaIroData/Package.swift                   # + GRDB.swift 7.x dep
packages/AwaIroPresentation/Package.swift           # + swift-snapshot-testing test dep
Makefile                                            # + test-ios target, + test-snapshot target
README.md                                           # update sprint status, add iOS run instructions
.gitignore                                          # + App/AwaIro.xcodeproj/xcuserdata/
```

---

## Conventions for All Tasks

- **TDD discipline:** Red (write failing test) → Verify Red → Green (impl) → Verify Green → Commit
- **Each commit gets `Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>` trailer**
- **HITL operations** (Package.swift edit, dep add, App Target creation): Orchestrator handles directly; subagents skip and report back
- **`make verify` after each task** to confirm regression-free
- **Concept Guardrail G3**: HomeScreen MUST NOT display numeric metrics (likes / followers / views / counts). Snapshot test in Task 9 enforces

---

## Task 0a: Add GRDB.swift dependency to AwaIroData

**🔴 HITL — orchestrator handles directly. Subagent must SKIP this task and report DONE-DELEGATED if dispatched on it.**

**Files:**
- Modify: `packages/AwaIroData/Package.swift`

This task triggers two HITL gates: (1) Package.swift edit (sensitive file via `hitl-edit-gate.sh`), (2) eventual SPM resolve will fetch a new dependency. Both require explicit user approval.

- [ ] **Step 1: User approves GRDB dep addition**

Orchestrator presents to user:
> "About to add `https://github.com/groue/GRDB.swift` (range `from: "7.0.0"`) to `packages/AwaIroData`. This is the first new dependency since Phase 0. GRDB is the SQL persistence chosen in ADR 0001. OK to proceed?"

Wait for explicit "OK" or equivalent before continuing.

- [ ] **Step 2: Update Package.swift**

Replace contents of `packages/AwaIroData/Package.swift`:

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AwaIroData",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "AwaIroData", targets: ["AwaIroData"])
    ],
    dependencies: [
        .package(path: "../AwaIroDomain"),
        .package(url: "https://github.com/groue/GRDB.swift", from: "7.0.0")
    ],
    targets: [
        .target(name: "AwaIroData", dependencies: [
            .product(name: "AwaIroDomain", package: "AwaIroDomain"),
            .product(name: "GRDB", package: "GRDB.swift")
        ]),
        .testTarget(name: "AwaIroDataTests", dependencies: ["AwaIroData"])
    ]
)
```

- [ ] **Step 3: Resolve and verify build still passes**

```bash
cd packages/AwaIroData && swift package resolve && swift build 2>&1 | tail -5
```

Expected: GRDB downloads, package builds.

- [ ] **Step 4: Commit**

```bash
git add packages/AwaIroData/Package.swift packages/AwaIroData/Package.resolved
git commit -m "$(cat <<'EOF'
build(data): add GRDB.swift 7.x dependency to AwaIroData

GRDB is the SQL persistence chosen in ADR 0001 — closest analogue
to SQLDelight for future Android Room migration.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 0b: Add swift-snapshot-testing dependency to AwaIroPresentation

**🔴 HITL — orchestrator handles directly. Subagent must SKIP if dispatched.**

**Files:**
- Modify: `packages/AwaIroPresentation/Package.swift`

Same HITL pattern as Task 0a. swift-snapshot-testing is added ONLY to the test target (not to product) so app users don't pay the dep cost.

- [ ] **Step 1: User approves**

Orchestrator presents:
> "About to add `https://github.com/pointfreeco/swift-snapshot-testing` (range `from: "1.16.0"`) to `packages/AwaIroPresentation` testTarget. Used for HomeScreen snapshot test (G3 guardrail enforcement). OK?"

Wait for OK.

- [ ] **Step 2: Update Package.swift**

Replace contents of `packages/AwaIroPresentation/Package.swift`:

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AwaIroPresentation",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "AwaIroPresentation", targets: ["AwaIroPresentation"])
    ],
    dependencies: [
        .package(path: "../AwaIroDomain"),
        .package(path: "../AwaIroPlatform"),
        .package(url: "https://github.com/pointfreeco/swift-snapshot-testing", from: "1.16.0")
    ],
    targets: [
        .target(name: "AwaIroPresentation", dependencies: [
            .product(name: "AwaIroDomain", package: "AwaIroDomain"),
            .product(name: "AwaIroPlatform", package: "AwaIroPlatform")
        ]),
        .testTarget(name: "AwaIroPresentationTests", dependencies: [
            "AwaIroPresentation",
            .product(name: "SnapshotTesting", package: "swift-snapshot-testing")
        ])
    ]
)
```

- [ ] **Step 3: Resolve and build**

```bash
cd packages/AwaIroPresentation && swift package resolve && swift build 2>&1 | tail -5
```

Expected: swift-snapshot-testing downloads, builds clean.

- [ ] **Step 4: Commit**

```bash
git add packages/AwaIroPresentation/Package.swift packages/AwaIroPresentation/Package.resolved
git commit -m "$(cat <<'EOF'
build(presentation): add swift-snapshot-testing 1.x to test target

Required for G3 guardrail snapshot tests (no numeric metrics in
HomeScreen). Test-only — not in product dependencies.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 1: Domain — Photo value type

**Files:**
- Create: `packages/AwaIroDomain/Sources/AwaIroDomain/Models/Photo.swift`
- Create: `packages/AwaIroDomain/Tests/AwaIroDomainTests/PhotoTests.swift`

`Photo` is a Pure Swift value type representing a single recorded photo. Value type (struct) with `Hashable`, `Codable`, `Sendable` conformance. NO Foundation-specific types beyond `Date`, `URL`, `UUID`.

- [ ] **Step 1: Create directory**

```bash
mkdir -p packages/AwaIroDomain/Sources/AwaIroDomain/Models
```

- [ ] **Step 2: Write failing test**

Create `packages/AwaIroDomain/Tests/AwaIroDomainTests/PhotoTests.swift`:

```swift
import Foundation
import Testing
@testable import AwaIroDomain

@Suite("Photo value type")
struct PhotoTests {
    @Test("equal photos have equal hash and equality")
    func equality() {
        let id = UUID()
        let now = Date(timeIntervalSince1970: 1_730_000_000)
        let url = URL(fileURLWithPath: "/tmp/x.jpg")
        let a = Photo(id: id, takenAt: now, fileURL: url, memo: "morning walk")
        let b = Photo(id: id, takenAt: now, fileURL: url, memo: "morning walk")
        #expect(a == b)
        #expect(a.hashValue == b.hashValue)
    }

    @Test("memo is optional")
    func optionalMemo() {
        let p = Photo(id: UUID(), takenAt: Date(), fileURL: URL(fileURLWithPath: "/x.jpg"), memo: nil)
        #expect(p.memo == nil)
    }

    @Test("Codable round-trip preserves all fields")
    func codableRoundTrip() throws {
        let original = Photo(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            takenAt: Date(timeIntervalSince1970: 1_730_000_000),
            fileURL: URL(fileURLWithPath: "/tmp/x.jpg"),
            memo: "nuance"
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Photo.self, from: data)
        #expect(decoded == original)
    }
}
```

- [ ] **Step 3: Run test to verify it fails**

```bash
cd packages/AwaIroDomain && swift test --filter PhotoTests 2>&1 | tail -10
```

Expected: FAIL with "cannot find Photo in scope".

- [ ] **Step 4: Write minimal implementation**

Create `packages/AwaIroDomain/Sources/AwaIroDomain/Models/Photo.swift`:

```swift
import Foundation

public struct Photo: Hashable, Codable, Sendable {
    public let id: UUID
    public let takenAt: Date
    public let fileURL: URL
    public let memo: String?

    public init(id: UUID, takenAt: Date, fileURL: URL, memo: String?) {
        self.id = id
        self.takenAt = takenAt
        self.fileURL = fileURL
        self.memo = memo
    }
}
```

- [ ] **Step 5: Verify test passes**

```bash
cd packages/AwaIroDomain && swift test --filter PhotoTests 2>&1 | tail -10
```

Expected: 3 tests passed.

- [ ] **Step 6: Commit**

```bash
git add packages/AwaIroDomain/Sources/AwaIroDomain/Models/Photo.swift packages/AwaIroDomain/Tests/AwaIroDomainTests/PhotoTests.swift
git commit -m "$(cat <<'EOF'
feat(domain): add Photo value type

Pure Swift struct with Hashable, Codable, Sendable. Holds id, takenAt,
fileURL, optional memo. No iOS framework imports — Android-portable.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: Domain — PhotoRepository protocol

**Files:**
- Create: `packages/AwaIroDomain/Sources/AwaIroDomain/Repositories/PhotoRepository.swift`

A protocol defining the persistence interface. Implementation lives in AwaIroData. No test for the protocol itself (protocols are tested through implementations and use cases).

- [ ] **Step 1: Create directory**

```bash
mkdir -p packages/AwaIroDomain/Sources/AwaIroDomain/Repositories
```

- [ ] **Step 2: Write the protocol**

Create `packages/AwaIroDomain/Sources/AwaIroDomain/Repositories/PhotoRepository.swift`:

```swift
import Foundation

public protocol PhotoRepository: Sendable {
    /// Fetches the photo recorded on the same calendar day (device local) as `now`.
    /// Returns nil if no photo recorded today.
    func todayPhoto(now: Date) async throws -> Photo?

    /// Inserts a new photo. Assumes caller has already enforced "1日1枚" guardrail (G1) at use case level.
    func insert(_ photo: Photo) async throws
}
```

- [ ] **Step 3: Verify package still builds**

```bash
cd packages/AwaIroDomain && swift build 2>&1 | tail -5
```

Expected: clean build.

- [ ] **Step 4: Commit**

```bash
git add packages/AwaIroDomain/Sources/AwaIroDomain/Repositories/PhotoRepository.swift
git commit -m "$(cat <<'EOF'
feat(domain): add PhotoRepository protocol

Sendable protocol with todayPhoto and insert. Implementation in
AwaIroData (Phase 1 Task 5). Guardrail G1 (1日1枚) enforced at
UseCase level, not Repository.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: Domain — GetTodayPhotoUseCase

**Files:**
- Create: `packages/AwaIroDomain/Sources/AwaIroDomain/UseCases/GetTodayPhotoUseCase.swift`
- Create: `packages/AwaIroDomain/Tests/AwaIroDomainTests/GetTodayPhotoUseCaseTests.swift`

Returns the photo for today (if any). Pure delegation to repository. Phase 1's only UseCase — Phase 2 will add `RecordPhotoUseCase` etc.

- [ ] **Step 1: Create directory**

```bash
mkdir -p packages/AwaIroDomain/Sources/AwaIroDomain/UseCases
```

- [ ] **Step 2: Write failing test (uses in-line stub repository)**

Create `packages/AwaIroDomain/Tests/AwaIroDomainTests/GetTodayPhotoUseCaseTests.swift`:

```swift
import Foundation
import Testing
@testable import AwaIroDomain

@Suite("GetTodayPhotoUseCase")
struct GetTodayPhotoUseCaseTests {
    @Test("returns nil when repository has no photo today")
    func returnsNilWhenEmpty() async throws {
        let repo = StubPhotoRepository(todayPhoto: nil)
        let usecase = GetTodayPhotoUseCase(repository: repo)
        let result = try await usecase.execute(now: Date())
        #expect(result == nil)
    }

    @Test("returns the photo when repository has one")
    func returnsPhotoWhenPresent() async throws {
        let now = Date(timeIntervalSince1970: 1_730_000_000)
        let photo = Photo(
            id: UUID(),
            takenAt: now,
            fileURL: URL(fileURLWithPath: "/tmp/today.jpg"),
            memo: nil
        )
        let repo = StubPhotoRepository(todayPhoto: photo)
        let usecase = GetTodayPhotoUseCase(repository: repo)
        let result = try await usecase.execute(now: now)
        #expect(result == photo)
    }

    @Test("propagates repository errors")
    func propagatesError() async {
        struct Boom: Error {}
        let repo = StubPhotoRepository(error: Boom())
        let usecase = GetTodayPhotoUseCase(repository: repo)
        await #expect(throws: Boom.self) {
            _ = try await usecase.execute(now: Date())
        }
    }
}

private struct StubPhotoRepository: PhotoRepository {
    let todayPhotoValue: Photo?
    let throwError: (any Error)?

    init(todayPhoto: Photo?) {
        self.todayPhotoValue = todayPhoto
        self.throwError = nil
    }

    init(error: any Error) {
        self.todayPhotoValue = nil
        self.throwError = error
    }

    func todayPhoto(now: Date) async throws -> Photo? {
        if let throwError { throw throwError }
        return todayPhotoValue
    }

    func insert(_ photo: Photo) async throws {
        // Not used in these tests
    }
}
```

- [ ] **Step 3: Run test to verify it fails**

```bash
cd packages/AwaIroDomain && swift test --filter GetTodayPhotoUseCaseTests 2>&1 | tail -10
```

Expected: FAIL — "cannot find GetTodayPhotoUseCase".

- [ ] **Step 4: Write minimal implementation**

Create `packages/AwaIroDomain/Sources/AwaIroDomain/UseCases/GetTodayPhotoUseCase.swift`:

```swift
import Foundation

public struct GetTodayPhotoUseCase: Sendable {
    private let repository: any PhotoRepository

    public init(repository: any PhotoRepository) {
        self.repository = repository
    }

    public func execute(now: Date) async throws -> Photo? {
        try await repository.todayPhoto(now: now)
    }
}
```

- [ ] **Step 5: Verify test passes**

```bash
cd packages/AwaIroDomain && swift test --filter GetTodayPhotoUseCaseTests 2>&1 | tail -10
```

Expected: 3 tests passed.

- [ ] **Step 6: Remove the placeholder test from Phase 0**

Phase 0 created a placeholder test that just verified `AwaIroDomain.moduleName == "AwaIroDomain"`. Now that we have real domain types, remove that placeholder along with the placeholder source.

```bash
rm packages/AwaIroDomain/Tests/AwaIroDomainTests/AwaIroDomainTests.swift
rm packages/AwaIroDomain/Sources/AwaIroDomain/AwaIroDomain.swift
```

Verify:

```bash
cd packages/AwaIroDomain && swift test 2>&1 | tail -10
```

Expected: 3 + 3 = 6 tests passed (PhotoTests + GetTodayPhotoUseCaseTests). The placeholder test is gone.

- [ ] **Step 7: Commit**

```bash
git add packages/AwaIroDomain/Sources/AwaIroDomain/UseCases/GetTodayPhotoUseCase.swift packages/AwaIroDomain/Tests/AwaIroDomainTests/GetTodayPhotoUseCaseTests.swift
git rm packages/AwaIroDomain/Tests/AwaIroDomainTests/AwaIroDomainTests.swift packages/AwaIroDomain/Sources/AwaIroDomain/AwaIroDomain.swift
git commit -m "$(cat <<'EOF'
feat(domain): add GetTodayPhotoUseCase + drop Phase 0 placeholder

UseCase delegates to PhotoRepository. Tests cover empty / present /
error-propagation cases via inline StubPhotoRepository.

Removes the Phase 0 placeholder enum AwaIroDomain and its test now
that real domain types are present.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 4: Data — DatabaseFactory + Photo migration v1

**Files:**
- Create: `packages/AwaIroData/Sources/AwaIroData/Database/DatabaseFactory.swift`
- Create: `packages/AwaIroData/Sources/AwaIroData/Database/Migrations.swift`
- Create: `packages/AwaIroData/Tests/AwaIroDataTests/MigrationsTests.swift`

`DatabaseFactory` exposes a function to build a `DatabasePool` (GRDB) — file-backed for app, in-memory for tests. Migrations sets up the `photos` table with id (TEXT, PK), taken_at (REAL, ISO timestamp), file_url (TEXT), memo (TEXT, NULL).

- [ ] **Step 1: Create directory**

```bash
mkdir -p packages/AwaIroData/Sources/AwaIroData/Database
```

- [ ] **Step 2: Write failing migration test**

Create `packages/AwaIroData/Tests/AwaIroDataTests/MigrationsTests.swift`:

```swift
import Foundation
import GRDB
import Testing
@testable import AwaIroData

@Suite("Migrations")
struct MigrationsTests {
    @Test("v1 creates photos table with expected columns")
    func v1CreatesPhotosTable() throws {
        let dbQueue = try DatabaseQueue() // in-memory
        try Migrations.applyAll(to: dbQueue)

        try dbQueue.read { db in
            let columns = try db.columns(in: "photos")
            let names = columns.map(\.name).sorted()
            #expect(names == ["file_url", "id", "memo", "taken_at"])
        }
    }

    @Test("applyAll is idempotent")
    func idempotent() throws {
        let dbQueue = try DatabaseQueue()
        try Migrations.applyAll(to: dbQueue)
        try Migrations.applyAll(to: dbQueue) // second call shouldn't error
        try dbQueue.read { db in
            #expect(try db.tableExists("photos"))
        }
    }
}
```

- [ ] **Step 3: Run to verify failure**

```bash
cd packages/AwaIroData && swift test --filter MigrationsTests 2>&1 | tail -10
```

Expected: FAIL — Migrations / DatabaseFactory not found.

- [ ] **Step 4: Implement Migrations**

Create `packages/AwaIroData/Sources/AwaIroData/Database/Migrations.swift`:

```swift
import GRDB

public enum Migrations {
    /// Apply all migrations in order. Idempotent.
    public static func applyAll(to writer: any DatabaseWriter) throws {
        var migrator = DatabaseMigrator()
        registerV1(in: &migrator)
        try migrator.migrate(writer)
    }

    private static func registerV1(in migrator: inout DatabaseMigrator) {
        migrator.registerMigration("v1_create_photos") { db in
            try db.create(table: "photos") { t in
                t.column("id", .text).primaryKey()
                t.column("taken_at", .double).notNull().indexed()
                t.column("file_url", .text).notNull()
                t.column("memo", .text)
            }
        }
    }
}
```

- [ ] **Step 5: Implement DatabaseFactory**

Create `packages/AwaIroData/Sources/AwaIroData/Database/DatabaseFactory.swift`:

```swift
import Foundation
import GRDB

public enum DatabaseFactory {
    /// Production: file-backed DatabasePool at the given URL.
    /// Migrations are applied automatically on creation.
    public static func makePool(at url: URL) throws -> DatabasePool {
        let pool = try DatabasePool(path: url.path)
        try Migrations.applyAll(to: pool)
        return pool
    }

    /// Tests: in-memory DatabaseQueue. Migrations applied.
    public static func makeInMemoryQueue() throws -> DatabaseQueue {
        let queue = try DatabaseQueue()
        try Migrations.applyAll(to: queue)
        return queue
    }
}
```

- [ ] **Step 6: Verify tests pass**

```bash
cd packages/AwaIroData && swift test --filter MigrationsTests 2>&1 | tail -10
```

Expected: 2 tests passed.

- [ ] **Step 7: Commit**

```bash
git add packages/AwaIroData/Sources/AwaIroData/Database packages/AwaIroData/Tests/AwaIroDataTests/MigrationsTests.swift
git commit -m "$(cat <<'EOF'
feat(data): add DatabaseFactory and Migrations v1

DatabaseFactory exposes file-backed DatabasePool (production) and
in-memory DatabaseQueue (tests). Migrations.applyAll runs all
registered migrations idempotently.

v1 creates the photos table:
- id TEXT PRIMARY KEY
- taken_at REAL NOT NULL INDEXED
- file_url TEXT NOT NULL
- memo TEXT (nullable)

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 5: Data — PhotoRepositoryImpl (GRDB-backed)

**Files:**
- Create: `packages/AwaIroData/Sources/AwaIroData/Repositories/PhotoRepositoryImpl.swift`
- Create: `packages/AwaIroData/Tests/AwaIroDataTests/PhotoRepositoryImplTests.swift`

Concrete implementation of `PhotoRepository` using GRDB. `todayPhoto(now:)` queries by date range (start-of-day to end-of-day, device local). `insert` saves a row.

- [ ] **Step 1: Create directory**

```bash
mkdir -p packages/AwaIroData/Sources/AwaIroData/Repositories
```

- [ ] **Step 2: Write failing test**

Create `packages/AwaIroData/Tests/AwaIroDataTests/PhotoRepositoryImplTests.swift`:

```swift
import Foundation
import GRDB
import Testing
import AwaIroDomain
@testable import AwaIroData

@Suite("PhotoRepositoryImpl")
struct PhotoRepositoryImplTests {

    private func makeRepo() throws -> (PhotoRepositoryImpl, DatabaseQueue) {
        let queue = try DatabaseFactory.makeInMemoryQueue()
        return (PhotoRepositoryImpl(writer: queue), queue)
    }

    @Test("todayPhoto returns nil when DB is empty")
    func emptyReturnsNil() async throws {
        let (repo, _) = try makeRepo()
        let result = try await repo.todayPhoto(now: Date())
        #expect(result == nil)
    }

    @Test("todayPhoto returns the photo recorded on the same calendar day as now")
    func sameDayReturnsPhoto() async throws {
        let (repo, _) = try makeRepo()
        let cal = Calendar.current
        let baseDay = cal.date(from: DateComponents(year: 2026, month: 5, day: 4, hour: 9))!
        let queryNow = cal.date(from: DateComponents(year: 2026, month: 5, day: 4, hour: 23))!

        let photo = Photo(
            id: UUID(),
            takenAt: baseDay,
            fileURL: URL(fileURLWithPath: "/tmp/x.jpg"),
            memo: "x"
        )
        try await repo.insert(photo)

        let result = try await repo.todayPhoto(now: queryNow)
        #expect(result == photo)
    }

    @Test("todayPhoto returns nil when only photo is from yesterday")
    func yesterdayReturnsNil() async throws {
        let (repo, _) = try makeRepo()
        let cal = Calendar.current
        let yesterday = cal.date(from: DateComponents(year: 2026, month: 5, day: 3, hour: 12))!
        let today = cal.date(from: DateComponents(year: 2026, month: 5, day: 4, hour: 12))!

        try await repo.insert(Photo(
            id: UUID(), takenAt: yesterday,
            fileURL: URL(fileURLWithPath: "/tmp/y.jpg"), memo: nil
        ))

        let result = try await repo.todayPhoto(now: today)
        #expect(result == nil)
    }

    @Test("insert then read preserves all fields")
    func insertReadRoundTrip() async throws {
        let (repo, _) = try makeRepo()
        let now = Date(timeIntervalSince1970: 1_730_000_000)
        let original = Photo(
            id: UUID(),
            takenAt: now,
            fileURL: URL(fileURLWithPath: "/tmp/round.jpg"),
            memo: "round-trip memo"
        )
        try await repo.insert(original)
        let result = try await repo.todayPhoto(now: now)
        #expect(result == original)
    }
}
```

- [ ] **Step 3: Run to verify failure**

```bash
cd packages/AwaIroData && swift test --filter PhotoRepositoryImplTests 2>&1 | tail -10
```

Expected: FAIL — PhotoRepositoryImpl not found.

- [ ] **Step 4: Implement PhotoRepositoryImpl**

Create `packages/AwaIroData/Sources/AwaIroData/Repositories/PhotoRepositoryImpl.swift`:

```swift
import Foundation
import GRDB
import AwaIroDomain

public final class PhotoRepositoryImpl: PhotoRepository, @unchecked Sendable {
    private let writer: any DatabaseWriter

    public init(writer: any DatabaseWriter) {
        self.writer = writer
    }

    public func todayPhoto(now: Date) async throws -> Photo? {
        let cal = Calendar.current
        let startOfDay = cal.startOfDay(for: now)
        let endOfDay = cal.date(byAdding: .day, value: 1, to: startOfDay)!

        return try await writer.read { db in
            let row = try Row.fetchOne(
                db,
                sql: """
                    SELECT id, taken_at, file_url, memo
                    FROM photos
                    WHERE taken_at >= ? AND taken_at < ?
                    ORDER BY taken_at DESC
                    LIMIT 1
                """,
                arguments: [startOfDay.timeIntervalSince1970, endOfDay.timeIntervalSince1970]
            )
            return row.map(Photo.init(row:))
        }
    }

    public func insert(_ photo: Photo) async throws {
        try await writer.write { db in
            try db.execute(
                sql: """
                    INSERT INTO photos (id, taken_at, file_url, memo)
                    VALUES (?, ?, ?, ?)
                """,
                arguments: [
                    photo.id.uuidString,
                    photo.takenAt.timeIntervalSince1970,
                    photo.fileURL.absoluteString,
                    photo.memo
                ]
            )
        }
    }
}

private extension Photo {
    init(row: Row) {
        self.init(
            id: UUID(uuidString: row["id"])!,
            takenAt: Date(timeIntervalSince1970: row["taken_at"]),
            fileURL: URL(string: row["file_url"])!,
            memo: row["memo"]
        )
    }
}
```

- [ ] **Step 5: Verify tests pass**

```bash
cd packages/AwaIroData && swift test --filter PhotoRepositoryImplTests 2>&1 | tail -10
```

Expected: 4 tests passed.

- [ ] **Step 6: Drop Phase 0 placeholder**

```bash
rm packages/AwaIroData/Tests/AwaIroDataTests/AwaIroDataTests.swift
rm packages/AwaIroData/Sources/AwaIroData/AwaIroData.swift
cd packages/AwaIroData && swift test 2>&1 | tail -5
```

Expected: 2 (Migrations) + 4 (RepoImpl) = 6 tests passed.

- [ ] **Step 7: Commit**

```bash
git add packages/AwaIroData/Sources/AwaIroData/Repositories packages/AwaIroData/Tests/AwaIroDataTests/PhotoRepositoryImplTests.swift
git rm packages/AwaIroData/Tests/AwaIroDataTests/AwaIroDataTests.swift packages/AwaIroData/Sources/AwaIroData/AwaIroData.swift
git commit -m "$(cat <<'EOF'
feat(data): add PhotoRepositoryImpl backed by GRDB

todayPhoto queries the photos table for any row whose taken_at falls
within the device-local calendar day of `now`. insert writes a single
row. Tests verify empty / same-day / yesterday / round-trip cases.

Drops the Phase 0 placeholder enum AwaIroData.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 6: Platform — FilePathProvider

**Files:**
- Create: `packages/AwaIroPlatform/Sources/AwaIroPlatform/Files/FilePathProvider.swift`
- Create: `packages/AwaIroPlatform/Tests/AwaIroPlatformTests/FilePathProviderTests.swift`

Provides URLs for app-managed files (DB, photos directory). Phase 1 only needs `databaseURL` for the SQLite file. `photoDirectory` will be added in Phase 2 when camera arrives.

- [ ] **Step 1: Create directory**

```bash
mkdir -p packages/AwaIroPlatform/Sources/AwaIroPlatform/Files
```

- [ ] **Step 2: Write failing test**

Create `packages/AwaIroPlatform/Tests/AwaIroPlatformTests/FilePathProviderTests.swift`:

```swift
import Foundation
import Testing
@testable import AwaIroPlatform

@Suite("FilePathProvider")
struct FilePathProviderTests {
    @Test("databaseURL returns a path under the supplied root")
    func databaseURLUnderRoot() {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("awairo-test-\(UUID().uuidString)")
        let provider = FilePathProvider(rootDirectory: tmp)
        let url = provider.databaseURL
        #expect(url.path.hasPrefix(tmp.path))
        #expect(url.lastPathComponent == "awairo.sqlite")
    }

    @Test("databaseURL parent directory exists after access")
    func databaseURLEnsuresDirectory() throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("awairo-test-\(UUID().uuidString)")
        let provider = FilePathProvider(rootDirectory: tmp)
        _ = provider.databaseURL
        var isDir: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: tmp.path, isDirectory: &isDir)
        #expect(exists && isDir.boolValue)
    }
}
```

- [ ] **Step 3: Run to verify failure**

```bash
cd packages/AwaIroPlatform && swift test --filter FilePathProviderTests 2>&1 | tail -10
```

Expected: FAIL — FilePathProvider not found.

- [ ] **Step 4: Implement**

Create `packages/AwaIroPlatform/Sources/AwaIroPlatform/Files/FilePathProvider.swift`:

```swift
import Foundation

public struct FilePathProvider: Sendable {
    private let rootDirectory: URL
    private let fileManager: FileManager

    public init(rootDirectory: URL, fileManager: FileManager = .default) {
        self.rootDirectory = rootDirectory
        self.fileManager = fileManager
    }

    /// Production convenience: rooted at the app's Application Support directory.
    public static func defaultProduction() throws -> FilePathProvider {
        let appSupport = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ).appendingPathComponent("AwaIro", isDirectory: true)
        return FilePathProvider(rootDirectory: appSupport)
    }

    public var databaseURL: URL {
        ensureRootExists()
        return rootDirectory.appendingPathComponent("awairo.sqlite")
    }

    private func ensureRootExists() {
        try? fileManager.createDirectory(at: rootDirectory, withIntermediateDirectories: true)
    }
}
```

- [ ] **Step 5: Verify tests pass**

```bash
cd packages/AwaIroPlatform && swift test --filter FilePathProviderTests 2>&1 | tail -10
```

Expected: 2 tests passed.

- [ ] **Step 6: Drop Phase 0 placeholder**

```bash
rm packages/AwaIroPlatform/Tests/AwaIroPlatformTests/AwaIroPlatformTests.swift
rm packages/AwaIroPlatform/Sources/AwaIroPlatform/AwaIroPlatform.swift
cd packages/AwaIroPlatform && swift test 2>&1 | tail -5
```

Expected: 2 tests passed.

- [ ] **Step 7: Commit**

```bash
git add packages/AwaIroPlatform/Sources/AwaIroPlatform/Files packages/AwaIroPlatform/Tests/AwaIroPlatformTests/FilePathProviderTests.swift
git rm packages/AwaIroPlatform/Tests/AwaIroPlatformTests/AwaIroPlatformTests.swift packages/AwaIroPlatform/Sources/AwaIroPlatform/AwaIroPlatform.swift
git commit -m "$(cat <<'EOF'
feat(platform): add FilePathProvider for app-managed file URLs

Provides databaseURL (rooted at supplied directory or Application
Support in production). Photos directory will be added in Phase 2
with camera. Tests use a temp directory to avoid polluting Application
Support.

Drops the Phase 0 placeholder enum AwaIroPlatform.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 7: Presentation — HomeViewModel

**Files:**
- Create: `packages/AwaIroPresentation/Sources/AwaIroPresentation/Home/HomeViewModel.swift`
- Create: `packages/AwaIroPresentation/Tests/AwaIroPresentationTests/HomeViewModelTests.swift`

`@Observable` ViewModel that exposes `state: HomeState` (`.unrecorded` or `.recorded`). `load()` is the entry point that calls `GetTodayPhotoUseCase` and updates state. Phase 1 only needs read; Phase 2 will add record action.

- [ ] **Step 1: Create directory**

```bash
mkdir -p packages/AwaIroPresentation/Sources/AwaIroPresentation/Home
```

- [ ] **Step 2: Write failing test**

Create `packages/AwaIroPresentation/Tests/AwaIroPresentationTests/HomeViewModelTests.swift`:

```swift
import Foundation
import Testing
import AwaIroDomain
@testable import AwaIroPresentation

@Suite("HomeViewModel")
struct HomeViewModelTests {
    @Test("initial state is .loading")
    @MainActor
    func initialState() {
        let vm = HomeViewModel(usecase: GetTodayPhotoUseCase(repository: StubRepo(value: nil)))
        #expect(vm.state == .loading)
    }

    @Test("load() with no today photo transitions to .unrecorded")
    @MainActor
    func loadEmpty() async {
        let vm = HomeViewModel(usecase: GetTodayPhotoUseCase(repository: StubRepo(value: nil)))
        await vm.load(now: Date())
        #expect(vm.state == .unrecorded)
    }

    @Test("load() with today photo transitions to .recorded")
    @MainActor
    func loadPresent() async {
        let now = Date()
        let photo = Photo(
            id: UUID(), takenAt: now,
            fileURL: URL(fileURLWithPath: "/tmp/x.jpg"), memo: nil
        )
        let vm = HomeViewModel(usecase: GetTodayPhotoUseCase(repository: StubRepo(value: photo)))
        await vm.load(now: now)
        #expect(vm.state == .recorded(photo))
    }

    @Test("load() error transitions to .failed")
    @MainActor
    func loadError() async {
        struct Boom: Error {}
        let vm = HomeViewModel(usecase: GetTodayPhotoUseCase(repository: StubRepo(error: Boom())))
        await vm.load(now: Date())
        if case .failed = vm.state {
            // ok
        } else {
            Issue.record("expected .failed, got \(vm.state)")
        }
    }
}

private struct StubRepo: PhotoRepository {
    let value: Photo?
    let error: (any Error)?

    init(value: Photo?) { self.value = value; self.error = nil }
    init(error: any Error) { self.value = nil; self.error = error }

    func todayPhoto(now: Date) async throws -> Photo? {
        if let error { throw error }
        return value
    }
    func insert(_ photo: Photo) async throws {}
}
```

- [ ] **Step 3: Run to verify failure**

```bash
cd packages/AwaIroPresentation && swift test --filter HomeViewModelTests 2>&1 | tail -10
```

Expected: FAIL — HomeViewModel not found.

- [ ] **Step 4: Implement**

Create `packages/AwaIroPresentation/Sources/AwaIroPresentation/Home/HomeViewModel.swift`:

```swift
import Foundation
import AwaIroDomain

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

    private let usecase: GetTodayPhotoUseCase

    public init(usecase: GetTodayPhotoUseCase) {
        self.usecase = usecase
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
    }
}
```

- [ ] **Step 5: Verify tests pass**

```bash
cd packages/AwaIroPresentation && swift test --filter HomeViewModelTests 2>&1 | tail -10
```

Expected: 4 tests passed.

- [ ] **Step 6: Commit**

```bash
git add packages/AwaIroPresentation/Sources/AwaIroPresentation/Home/HomeViewModel.swift packages/AwaIroPresentation/Tests/AwaIroPresentationTests/HomeViewModelTests.swift
git commit -m "$(cat <<'EOF'
feat(presentation): add HomeViewModel with @Observable

State machine: .loading → .unrecorded / .recorded(Photo) / .failed.
load(now:) delegates to GetTodayPhotoUseCase. @MainActor isolation
ensures state writes happen on the main thread for SwiftUI.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 8: Presentation — HomeScreen view

**Files:**
- Create: `packages/AwaIroPresentation/Sources/AwaIroPresentation/Home/HomeScreen.swift`

SwiftUI view that displays one of three states. Walking-skeleton-grade visuals (placeholder shapes, no camera, no bubble effect). NO numeric metrics anywhere (G3 guardrail).

- [ ] **Step 1: Implement HomeScreen**

Create `packages/AwaIroPresentation/Sources/AwaIroPresentation/Home/HomeScreen.swift`:

```swift
import SwiftUI

public struct HomeScreen: View {
    @State private var viewModel: HomeViewModel

    public init(viewModel: HomeViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    public var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            content
        }
        .task {
            await viewModel.load(now: Date())
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .loading:
            ProgressView()
                .tint(.white)
                .accessibilityLabel("読み込み中")

        case .unrecorded:
            Circle()
                .fill(.white.opacity(0.85))
                .frame(width: 200, height: 200)
                .accessibilityLabel("今日はまだ記録していません")

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

#Preview("unrecorded") {
    HomeScreen(viewModel: PreviewHelpers.unrecordedVM())
}

#Preview("recorded") {
    HomeScreen(viewModel: PreviewHelpers.recordedVM())
}
```

Note: `PreviewHelpers` is created in Task 9 (with the snapshot test).

- [ ] **Step 2: Verify build still passes**

```bash
cd packages/AwaIroPresentation && swift build 2>&1 | tail -5
```

If build fails because `PreviewHelpers` doesn't exist yet, that's OK — Task 9 adds it. Move on. Otherwise expected: clean build.

- [ ] **Step 3: Commit**

```bash
git add packages/AwaIroPresentation/Sources/AwaIroPresentation/Home/HomeScreen.swift
git commit -m "$(cat <<'EOF'
feat(presentation): add HomeScreen SwiftUI view

Walking-skeleton visual: black background + white circle (unrecorded)
or grayed circle (recorded) or progress / error text. No numeric
metrics, no camera, no bubble effect (those arrive in Phase 2).
G3 guardrail (数字なし) is preserved by construction — the View has
no Text containing numbers.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 9: Presentation — HomeScreen snapshot test (G3 guardrail)

**Files:**
- Create: `packages/AwaIroPresentation/Tests/AwaIroPresentationTests/HomeScreenSnapshotTests.swift`
- Create: `packages/AwaIroPresentation/Tests/AwaIroPresentationTests/Helpers/PreviewHelpers.swift`

Snapshot test that:
1. Renders HomeScreen and visually confirms layout (image diff)
2. Asserts the rendered View tree contains NO numeric metric strings (G3 guardrail enforcement)

This test runs ONLY on iOS Simulator (`#if canImport(UIKit)`); on macOS via `swift test` it's skipped automatically.

- [ ] **Step 1: Create directories**

```bash
mkdir -p packages/AwaIroPresentation/Tests/AwaIroPresentationTests/Helpers
```

- [ ] **Step 2: Create PreviewHelpers (used by both #Preview blocks and tests)**

Create `packages/AwaIroPresentation/Tests/AwaIroPresentationTests/Helpers/PreviewHelpers.swift`:

```swift
import Foundation
import AwaIroDomain
@testable import AwaIroPresentation

@MainActor
public enum PreviewHelpers {
    public static func unrecordedVM() -> HomeViewModel {
        HomeViewModel(usecase: GetTodayPhotoUseCase(repository: AlwaysEmptyRepo()))
    }

    public static func recordedVM() -> HomeViewModel {
        let photo = Photo(
            id: UUID(),
            takenAt: Date(),
            fileURL: URL(fileURLWithPath: "/tmp/preview.jpg"),
            memo: "preview"
        )
        return HomeViewModel(usecase: GetTodayPhotoUseCase(repository: AlwaysReturnRepo(photo: photo)))
    }
}

private struct AlwaysEmptyRepo: PhotoRepository {
    func todayPhoto(now: Date) async throws -> Photo? { nil }
    func insert(_ photo: Photo) async throws {}
}

private struct AlwaysReturnRepo: PhotoRepository {
    let photo: Photo
    func todayPhoto(now: Date) async throws -> Photo? { photo }
    func insert(_ photo: Photo) async throws {}
}
```

Wait — `PreviewHelpers` is referenced from the production `HomeScreen.swift` `#Preview` blocks. That means it must be reachable from the production target, not just tests. Let me move it.

- [ ] **Step 3: Move PreviewHelpers to production target as DEBUG-only**

Delete the test-target file:

```bash
rm packages/AwaIroPresentation/Tests/AwaIroPresentationTests/Helpers/PreviewHelpers.swift
rmdir packages/AwaIroPresentation/Tests/AwaIroPresentationTests/Helpers 2>/dev/null || true
```

Create `packages/AwaIroPresentation/Sources/AwaIroPresentation/Home/PreviewHelpers.swift`:

```swift
#if DEBUG
import Foundation
import AwaIroDomain

@MainActor
public enum PreviewHelpers {
    public static func unrecordedVM() -> HomeViewModel {
        HomeViewModel(usecase: GetTodayPhotoUseCase(repository: AlwaysEmptyRepo()))
    }

    public static func recordedVM() -> HomeViewModel {
        let photo = Photo(
            id: UUID(),
            takenAt: Date(),
            fileURL: URL(fileURLWithPath: "/tmp/preview.jpg"),
            memo: "preview"
        )
        return HomeViewModel(usecase: GetTodayPhotoUseCase(repository: AlwaysReturnRepo(photo: photo)))
    }
}

private struct AlwaysEmptyRepo: PhotoRepository {
    func todayPhoto(now: Date) async throws -> Photo? { nil }
    func insert(_ photo: Photo) async throws {}
}

private struct AlwaysReturnRepo: PhotoRepository {
    let photo: Photo
    func todayPhoto(now: Date) async throws -> Photo? { photo }
    func insert(_ photo: Photo) async throws {}
}
#endif
```

- [ ] **Step 4: Verify production build still works**

```bash
cd packages/AwaIroPresentation && swift build 2>&1 | tail -5
```

Expected: clean build.

- [ ] **Step 5: Write the snapshot test (iOS-only)**

Create `packages/AwaIroPresentation/Tests/AwaIroPresentationTests/HomeScreenSnapshotTests.swift`:

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

    /// G3 guardrail: View ツリーに「いいね数」「フォロワー」「閲覧」等の他者評価指標が現れないこと。
    /// この test は禁止語が UI 文字列として描画されていないことを assert する。
    private let prohibitedWords: [String] = [
        "いいね", "Like", "Likes",
        "フォロワー", "Follower", "Followers",
        "閲覧", "Views", "View count",
        "シェア数", "Shares"
    ]

    @Test("unrecorded snapshot is stable")
    func unrecordedSnapshot() {
        let view = HomeScreen(viewModel: PreviewHelpers.unrecordedVM())
        let host = UIHostingController(rootView: view)
        assertSnapshot(of: host, as: .image(on: .iPhone15(.portrait)))
    }

    @Test("recorded snapshot is stable")
    func recordedSnapshot() {
        let view = HomeScreen(viewModel: PreviewHelpers.recordedVM())
        let host = UIHostingController(rootView: view)
        assertSnapshot(of: host, as: .image(on: .iPhone15(.portrait)))
    }

    @Test("HomeScreen contains no numeric-metric strings (G3)")
    func noNumericMetrics() {
        let view = HomeScreen(viewModel: PreviewHelpers.recordedVM())
        let host = UIHostingController(rootView: view)
        host.loadViewIfNeeded()
        host.view.frame = UIScreen.main.bounds
        host.view.layoutIfNeeded()

        let allText = collectText(in: host.view)
        for word in prohibitedWords {
            #expect(!allText.contains(word),
                    "G3 guardrail violation: '\(word)' appeared in HomeScreen view tree.\nFull text: \(allText)")
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

- [ ] **Step 6: Run snapshot test on iOS Simulator**

```bash
xcodebuild test \
  -workspace . \
  -scheme AwaIroPresentation \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -only-testing:AwaIroPresentationTests/HomeScreenSnapshotTests \
  2>&1 | tail -30
```

Note: this command requires the Xcode workspace to exist. If you don't have it yet, first generate it:

```bash
swift package --package-path packages/AwaIroPresentation generate-xcodeproj 2>/dev/null || \
  cd packages/AwaIroPresentation && xcodebuild test \
    -scheme AwaIroPresentation \
    -destination 'platform=iOS Simulator,name=iPhone 15' \
    -only-testing:AwaIroPresentationTests/HomeScreenSnapshotTests
```

Modern SPM packages can be tested directly without an Xcode project for iOS by using `xcodebuild test` with `-scheme` matching the package's library name.

Expected: First run RECORDS the snapshots (asserts fail with "snapshot recorded — re-run to verify"). Re-run the same command — snapshots should now match.

For the first record run, you may need to add `record: true` temporarily to `assertSnapshot(...)`, then remove it.

- [ ] **Step 7: Commit (after snapshots are recorded)**

```bash
git add packages/AwaIroPresentation/Sources/AwaIroPresentation/Home/PreviewHelpers.swift packages/AwaIroPresentation/Tests/AwaIroPresentationTests/HomeScreenSnapshotTests.swift packages/AwaIroPresentation/Tests/AwaIroPresentationTests/__Snapshots__/
git commit -m "$(cat <<'EOF'
feat(presentation): add HomeScreen snapshot tests + G3 guardrail enforcement

Two iOS-only snapshot tests (#if canImport(UIKit)) verify HomeScreen
unrecorded and recorded states render stably on iPhone 15 portrait.
A third test walks the rendered view tree and asserts none of the
prohibited words (いいね / Like / フォロワー / Follower / 閲覧 / Views /
シェア数) appear — concrete enforcement of Concept Guardrail G3.

PreviewHelpers moved to production target under #if DEBUG so #Preview
blocks in HomeScreen can reference them.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 10: Drop Phase 0 placeholder from AwaIroPresentation

**Files:**
- Delete: `packages/AwaIroPresentation/Sources/AwaIroPresentation/AwaIroPresentation.swift`
- Delete: `packages/AwaIroPresentation/Tests/AwaIroPresentationTests/AwaIroPresentationTests.swift`

- [ ] **Step 1: Remove placeholder source**

```bash
rm packages/AwaIroPresentation/Sources/AwaIroPresentation/AwaIroPresentation.swift
rm packages/AwaIroPresentation/Tests/AwaIroPresentationTests/AwaIroPresentationTests.swift
```

- [ ] **Step 2: Verify package still builds and tests still pass**

```bash
cd packages/AwaIroPresentation && swift test 2>&1 | tail -10
```

Expected: 4 (HomeViewModel) tests passed (snapshot tests skipped on macOS due to #if canImport(UIKit)).

- [ ] **Step 3: Commit**

```bash
git add -A packages/AwaIroPresentation
git commit -m "$(cat <<'EOF'
chore(presentation): drop Phase 0 placeholder enum

HomeScreen and HomeViewModel are now the real entry points.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 11: Create iOS App Target (manual Xcode UI)

**🔴 HITL — manual user step. Orchestrator presents instructions, user clicks through Xcode.**

The Xcode App Target is needed to run on iOS Simulator. The spec (ADR 0001) rules out third-party project generators (XcodeGen / Tuist) for now, so this is a one-time manual setup.

- [ ] **Step 1: Orchestrator presents instructions to user**

Quote to user verbatim:

> Phase 1 で iOS App Target を作成します。手順:
>
> 1. Xcode を開く
> 2. File → New → Project... → iOS タブ → **App** → Next
> 3. 設定:
>    - Product Name: `AwaIro`
>    - Team: (your team)
>    - Organization Identifier: `io.awairo` （または好みのドメイン）
>    - Bundle Identifier: 自動補完される（`io.awairo.AwaIro`）
>    - Interface: **SwiftUI**
>    - Language: **Swift**
>    - Storage: **None** （GRDB を使うので Core Data 不要）
>    - Include Tests: **チェック**
> 4. Save Location: `/Users/nodayouta/Documents/code/AwaIro/.claude/worktrees/hardcore-mccarthy-b2a51f/App/`
>    - 「Create Git repository on my Mac」は **チェック外す**（worktree 内）
> 5. 完了したら Xcode を閉じる
>
> 出来たら「OK」と返してください。私が後続コードを埋めます。

Wait for user to complete and confirm.

- [ ] **Step 2: Verify file structure**

```bash
ls -la App/
ls App/AwaIro/
```

Expected:
- `App/AwaIro.xcodeproj/`
- `App/AwaIro/AwaIroApp.swift` (template-generated)
- `App/AwaIro/ContentView.swift` (template-generated)
- `App/AwaIro/Assets.xcassets/`
- `App/AwaIroTests/` (template-generated XCTest)
- `App/AwaIroUITests/` (we won't use these in Phase 1)

- [ ] **Step 3: Update `.gitignore` for the new App subdirectory**

```bash
cat >> .gitignore <<'EOF'

# Xcode App Target user-specific files
App/AwaIro.xcodeproj/xcuserdata/
App/AwaIro.xcodeproj/project.xcworkspace/xcuserdata/
App/AwaIro.xcodeproj/project.xcworkspace/xcshareddata/IDEWorkspaceChecks.plist
EOF
```

- [ ] **Step 4: Commit the freshly-created App Target as-is**

```bash
git add App/ .gitignore
git commit -m "$(cat <<'EOF'
feat(app): scaffold iOS App Target via Xcode UI

Bare Xcode-template project (SwiftUI, no Core Data, with tests).
Following ADR 0001's no-XcodeGen policy, this is a manual one-time
setup. Subsequent tasks fill in AwaIroApp / RootContentView /
AppContainer and wire the SPM packages as dependencies.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 12: Add SPM packages as App Target dependencies (manual Xcode UI)

**🔴 HITL — manual user step.**

The 4 SPM packages need to be added to the AwaIro app target's "Package Dependencies".

- [ ] **Step 1: Orchestrator presents instructions**

Quote to user:

> 1. Xcode で `App/AwaIro.xcodeproj` を開く
> 2. Project Navigator で `AwaIro` プロジェクト（一番上）を選択
> 3. PROJECT 列 → AwaIro → Tab: **Package Dependencies** を開く
> 4. `+` ボタンを押す
> 5. ダイアログ左下の「Add Local...」を押す
> 6. `packages/AwaIroDomain` フォルダを選択 → Add Package
> 7. ターゲット選択ダイアログ: AwaIroDomain library を AwaIro target に追加
> 8. 同じ手順で AwaIroData / AwaIroPlatform / AwaIroPresentation も追加
> 9. Build (Cmd+B) してエラーが出ないことを確認
> 10. Xcode を閉じる
>
> 完了したら「OK」と返してください。

Wait for confirmation.

- [ ] **Step 2: Verify deps are wired in project.pbxproj**

```bash
grep -E '(AwaIroDomain|AwaIroData|AwaIroPlatform|AwaIroPresentation)' App/AwaIro.xcodeproj/project.pbxproj | head -20
```

Expected: each package name appears (in productDependencies and similar sections).

- [ ] **Step 3: Commit project changes**

```bash
git add App/AwaIro.xcodeproj/project.pbxproj App/AwaIro.xcodeproj/project.xcworkspace/contents.xcworkspacedata
git commit -m "$(cat <<'EOF'
build(app): wire 4 SPM packages as App Target dependencies via Xcode

Domain / Data / Platform / Presentation are added as Local packages
in App/AwaIro.xcodeproj. Manual one-time wiring per ADR 0001.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 13: Implement AppContainer (Composition Root)

**Files:**
- Create: `App/AwaIro/AppContainer.swift`

The Composition Root: builds the dependency graph manually (no third-party DI). Constructs FilePathProvider → DatabasePool → PhotoRepositoryImpl → GetTodayPhotoUseCase → HomeViewModel.

- [ ] **Step 1: Implement**

Create `App/AwaIro/AppContainer.swift`:

```swift
import Foundation
import AwaIroDomain
import AwaIroData
import AwaIroPlatform
import AwaIroPresentation

@MainActor
final class AppContainer {
    let filePathProvider: FilePathProvider
    let photoRepository: any PhotoRepository
    let getTodayPhotoUseCase: GetTodayPhotoUseCase

    init() throws {
        let provider = try FilePathProvider.defaultProduction()
        self.filePathProvider = provider

        let pool = try DatabaseFactory.makePool(at: provider.databaseURL)
        let repo = PhotoRepositoryImpl(writer: pool)
        self.photoRepository = repo

        self.getTodayPhotoUseCase = GetTodayPhotoUseCase(repository: repo)
    }

    func makeHomeViewModel() -> HomeViewModel {
        HomeViewModel(usecase: getTodayPhotoUseCase)
    }
}
```

- [ ] **Step 2: Verify compiles**

```bash
xcodebuild build \
  -workspace App/AwaIro.xcodeproj/project.xcworkspace \
  -scheme AwaIro \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  2>&1 | tail -10
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git add App/AwaIro/AppContainer.swift
git commit -m "$(cat <<'EOF'
feat(app): add AppContainer composition root

Hand-written DI: FilePathProvider → DatabasePool → PhotoRepositoryImpl
→ GetTodayPhotoUseCase → HomeViewModel. @MainActor isolated. No
third-party DI per ADR 0001.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 14: Wire AwaIroApp + RootContentView to HomeScreen

**Files:**
- Modify: `App/AwaIro/AwaIroApp.swift`
- Replace: `App/AwaIro/ContentView.swift` → `App/AwaIro/RootContentView.swift`

Replace Xcode template with our actual entry point: `AwaIroApp` constructs `AppContainer` once and passes it to `RootContentView`, which wraps `HomeScreen` in `NavigationStack`.

- [ ] **Step 1: Replace AwaIroApp.swift**

Overwrite `App/AwaIro/AwaIroApp.swift`:

```swift
import SwiftUI

@main
struct AwaIroApp: App {
    @State private var container: AppContainer?
    @State private var initError: String?

    var body: some Scene {
        WindowGroup {
            if let container {
                RootContentView(container: container)
            } else if let initError {
                Text("起動に失敗しました\n\(initError)")
                    .multilineTextAlignment(.center)
                    .padding()
            } else {
                ProgressView()
                    .task {
                        do {
                            container = try AppContainer()
                        } catch {
                            initError = String(describing: error)
                        }
                    }
            }
        }
    }
}
```

- [ ] **Step 2: Replace ContentView.swift with RootContentView.swift**

```bash
rm App/AwaIro/ContentView.swift
```

Create `App/AwaIro/RootContentView.swift`:

```swift
import SwiftUI
import AwaIroPresentation

struct RootContentView: View {
    let container: AppContainer

    var body: some View {
        NavigationStack {
            HomeScreen(viewModel: container.makeHomeViewModel())
                .navigationBarHidden(true)
        }
        .preferredColorScheme(.dark)
    }
}
```

- [ ] **Step 3: Build for Simulator**

```bash
xcodebuild build \
  -workspace App/AwaIro.xcodeproj/project.xcworkspace \
  -scheme AwaIro \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  2>&1 | tail -10
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 4: Commit**

```bash
git add App/AwaIro/AwaIroApp.swift App/AwaIro/RootContentView.swift
git rm App/AwaIro/ContentView.swift
git commit -m "$(cat <<'EOF'
feat(app): wire AwaIroApp → RootContentView → HomeScreen

AwaIroApp constructs AppContainer asynchronously on first appear.
RootContentView wraps HomeScreen in NavigationStack with hidden bar
(walking-skeleton: nothing else to navigate to yet) and forces dark
color scheme to match the concept (淡い光 in darkness).

Replaces the Xcode template ContentView.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 15: Add `make test-ios` to Makefile

**Files:**
- Modify: `Makefile`

Phase 0's `make test` runs `swift test` for each SPM package on macOS. Snapshot tests need iOS Simulator. Add `make test-ios` (xcodebuild) and include it in `make verify`.

- [ ] **Step 1: Update Makefile**

Edit `Makefile` — modify `verify` target and add `test-ios`. Replace these specific blocks:

```makefile
test-snapshot:
	@echo "Snapshot tests not yet enabled (Phase 2+)."
```

with:

```makefile
test-ios:
	@echo "==> xcodebuild test (App scheme on iPhone 15 Simulator)"
	@xcodebuild test \
		-workspace App/AwaIro.xcodeproj/project.xcworkspace \
		-scheme AwaIro \
		-destination 'platform=iOS Simulator,name=iPhone 15' \
		-quiet 2>&1 | grep -E '(Test|FAILED|PASSED|✗|✓|error:)' | tail -20

test-snapshot:
	@echo "==> Snapshot tests via xcodebuild"
	@xcodebuild test \
		-workspace App/AwaIro.xcodeproj/project.xcworkspace \
		-scheme AwaIroPresentation \
		-destination 'platform=iOS Simulator,name=iPhone 15' \
		-only-testing:AwaIroPresentationTests/HomeScreenSnapshotTests \
		-quiet 2>&1 | tail -10
```

And modify the `verify` target to include `test-ios`:

```makefile
verify: build test test-ios lint
	@echo ""
	@echo "✅ make verify passed (build + test + test-ios + lint)"
```

- [ ] **Step 2: Run make verify end-to-end**

```bash
make verify 2>&1 | tail -30
```

Expected:
- All 4 packages build
- All 4 packages' macOS tests pass (Domain: 6, Data: 6, Platform: 2, Presentation: 4)
- iOS xcodebuild test passes (snapshot tests pass on simulator)
- Lint passes
- `✅ make verify passed`

If iOS test fails because the App scheme can't be found, the user may need to open Xcode once and let it index, OR the App Target setup in Task 11 may have skipped some option. Investigate then re-run.

- [ ] **Step 3: Commit**

```bash
git add Makefile
git commit -m "$(cat <<'EOF'
build: add make test-ios and include it in make verify

test-ios runs xcodebuild test against the App scheme on iPhone 15
Simulator, covering snapshot tests that require UIKit. test-snapshot
narrows to only HomeScreenSnapshotTests for fast iteration.

verify now requires both macOS swift test (fast unit tests) and iOS
xcodebuild test (snapshot tests) to pass.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 16: Verify HomeScreen on iOS Simulator

**Files:**
- No file changes; verification + commit retro doc.

- [ ] **Step 1: Boot iPhone 15 Simulator**

```bash
xcrun simctl boot "iPhone 15" 2>/dev/null || true  # idempotent
open -a Simulator
sleep 5
xcrun simctl list devices booted
```

- [ ] **Step 2: Build & install AwaIro on the booted simulator**

```bash
xcodebuild \
  -workspace App/AwaIro.xcodeproj/project.xcworkspace \
  -scheme AwaIro \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -derivedDataPath build/ \
  build 2>&1 | tail -5

# Find the .app bundle and install + launch
APP_PATH=$(find build/Build/Products -name "AwaIro.app" -type d | head -1)
xcrun simctl install booted "$APP_PATH"
xcrun simctl launch booted io.awairo.AwaIro
```

(Bundle ID `io.awairo.AwaIro` assumes the user used the suggested Bundle Identifier in Task 11 Step 1. Adjust if different.)

- [ ] **Step 3: Manual visual verification**

Look at the Simulator window. Expected:
- Black background fills the screen
- A white circle (~200pt diameter) is centered on screen
- (You're seeing the `.unrecorded` state because no photo has ever been recorded — Phase 1 doesn't have a record action yet)

If you see this: **Phase 1 walking skeleton is alive end-to-end.**

If you see only black or a crash, check:
- `xcrun simctl spawn booted log stream --predicate 'process == "AwaIro"'` for runtime errors
- `AppContainer` init may have thrown; the failure path renders an error message — check for that

- [ ] **Step 4: Run the full make verify one more time as final DoD check**

```bash
make verify
```

Expected: green.

- [ ] **Step 5: Take a Simulator screenshot for posterity**

```bash
mkdir -p docs/snapshots/phase-1
xcrun simctl io booted screenshot docs/snapshots/phase-1/home-unrecorded-iphone15.png
```

- [ ] **Step 6: Commit screenshot**

```bash
git add docs/snapshots/phase-1/home-unrecorded-iphone15.png
git commit -m "$(cat <<'EOF'
docs(snapshot): capture Phase 1 HomeScreen unrecorded on iPhone 15

Walking skeleton verification artifact. White circle on black,
no numerics, no camera preview yet. Phase 2 will replace this with
the actual bubble + camera.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 17: Phase 1 retro and Phase 2 entry preparation

**Files:**
- Create: `docs/harness/phase1-retro.md`
- Modify: `README.md`

Captures friction points observed during Phase 1, decides Trust Ladder promotions/demotions, decides whether to add the remaining 3 agent definitions (test-engineer / devops / ux-designer), updates README.

- [ ] **Step 1: Create retro template**

Create `docs/harness/phase1-retro.md` (orchestrator + user fill in collaboratively at end of Phase 1 execution):

```markdown
# Phase 1 Retro — Walking Skeleton

Date: <YYYY-MM-DD>
Participants: nusnody, Orchestrator

## What worked

- (例) GRDB の SQL レイヤが SQLDelight 思考でそのまま書けて移行コスト低
- (例) HITL bypass 機構が PR 作成・dep 追加で実用的に動作
- ...

## What didn't (friction points)

- (例) Snapshot test の初回 record で `record: true` を一時的に書く運用が煩雑
- (例) iOS Simulator の起動待ち時間で feedback ループが遅い
- ...

## Trust Ladder decisions

| 操作 | 現在 | 提案 | 根拠 |
|------|------|------|------|
| Reviewer の trivial diff approve | HOTL | HOOTL | Phase 1 で N 件確認、誤検知ゼロ |
| ... | ... | ... | ... |

## Agent definitions to add

- [ ] test-engineer: 必要 / 不要（Phase 2 のテスト量に応じて判断）
- [ ] devops: 必要 / 不要（CI を本格化するなら必要）
- [ ] ux-designer: 必要 / 不要（Phase 2 で BubbleCameraView を組むなら必要）

## Spec/ADR updates needed

- [ ] (例) ADR 0001 に GRDB の使用バージョンを追記
- ...

## Phase 2 entry blockers

- [ ] (例) Camera permission の Info.plist 設定方針を決める
- ...
```

- [ ] **Step 2: Update README sprint status**

Edit `README.md`. Replace:

```markdown
| Conversion Phase 1 | Walking Skeleton | 📋 次フェーズ |
```

with:

```markdown
| Conversion Phase 1 | Walking Skeleton | ✅ 完了 |
| Conversion Phase 2 | Sprint 1 (記録) port | 🔨 次フェーズ |
```

(Adjust formatting to keep table alignment.)

- [ ] **Step 3: Commit retro doc + README update**

```bash
git add docs/harness/phase1-retro.md README.md
git commit -m "$(cat <<'EOF'
docs: add Phase 1 retro template + mark Phase 1 complete in README

Retro doc to be filled collaboratively at Phase 1 close-out (Trust
Ladder decisions, friction points, additional agent definitions to
create, Phase 2 entry blockers).

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 4: Final report to user (Phase 1 close-out)**

Report:

```
## Phase 1 Walking Skeleton 完了

✅ Domain: Photo + PhotoRepository + GetTodayPhotoUseCase (6 tests)
✅ Data: GRDB DatabaseFactory + Migrations v1 + PhotoRepositoryImpl (6 tests)
✅ Platform: FilePathProvider (2 tests)
✅ Presentation: HomeViewModel + HomeScreen (4 unit tests + 3 iOS snapshot tests including G3)
✅ App: Xcode App Target with AppContainer composition root
✅ HomeScreen renders on iPhone 15 Simulator
✅ make verify (build + macOS test + iOS test + lint) all green

### 次のアクション

1. Phase 1 retro 対話 (`docs/harness/phase1-retro.md` を一緒に埋める)
2. 追加エージェント定義（test-engineer / devops / ux-designer）の要否判断
3. Phase 2 plan 起こし（Sprint 1 記録機能 — Camera + MemoScreen + RecordPhotoUseCase + BubbleDistortion）
4. PR を作成する場合は別 PR にする (HITL)
```

---

## Self-Review

**Spec coverage check (Phase 1 deliverables from spec § Phase 1):**

| Spec deliverable | Plan task |
|------------------|-----------|
| Domain: Photo, PhotoRepository, GetTodayPhotoUseCase | Tasks 1, 2, 3 |
| Data: PhotoRepositoryImpl(GRDB), migration v1, Photo table | Tasks 4, 5 (GRDB dep added in Task 0a) |
| Platform: 最小 FilePathProvider | Task 6 |
| Presentation: HomeScreen + HomeViewModel + ナビゲーション枠 | Tasks 7, 8, 14 |
| Test: GetTodayPhotoUseCaseTests (in-memory GRDB) | Task 3 (uses StubPhotoRepository) and Task 5 (in-memory GRDB integration) |
| Test: HomeScreenSnapshotTests (数字なし guardrail 含む) | Task 9 (G3 enforced as separate test) |
| Done: Simulator で起動して HomeScreen 表示 | Tasks 11-14, verified in Task 16 |
| Done: テスト全緑 | Task 15 (`make verify` includes iOS) |
| Done: phase1-retro.md | Task 17 |
| Done: 残り 3 役と hooks/gate 肉付け | Task 17 leaves this as user-decision (out of plan scope) |

All Phase 1 deliverables covered.

**Placeholder scan:**
- No "TBD" / "TODO" / "fill in details"
- All code blocks contain actual code
- All commands have expected output

**Type / signature consistency:**
- `PhotoRepository` protocol methods (`todayPhoto(now:)`, `insert(_:)`) match across protocol definition (Task 2), test stubs (Tasks 3, 7), and impl (Task 5)
- `Photo` initializer signature `(id:takenAt:fileURL:memo:)` consistent across Tasks 1, 3, 5, 7, 9
- `HomeViewModel.load(now:)` matches between impl (Task 7) and test (Task 7) and View consumer (Task 8)
- `AppContainer.makeHomeViewModel()` (Task 13) → consumed in Task 14
- `FilePathProvider.databaseURL` (Task 6) → consumed in Task 13
- `GetTodayPhotoUseCase(repository:)` initializer consistent across Tasks 3 and 13

**Corrections made during self-review:**
1. Task 9 originally had PreviewHelpers in the test target, but `HomeScreen.swift` (Task 8) `#Preview` blocks reference it. Moved to production target under `#if DEBUG` so both consumers can see it. Updated Step numbers in Task 9.

---

## Notes for Executor

1. **HITL tasks** (0a, 0b, 11, 12) require orchestrator to handle directly with user-in-the-loop. Do NOT dispatch subagents on these.

2. **Snapshot test recording**: Task 9's first run will fail with "snapshot recorded". Re-run to verify. If you can't re-run because the file gets stale-checked, add `record: .all` parameter to assertSnapshot temporarily, then remove it.

3. **Xcode workspace path**: After Task 11, the workspace path is `App/AwaIro.xcodeproj/project.xcworkspace`. Use this for all xcodebuild invocations.

4. **iOS Simulator availability**: Tasks 9, 13, 14, 15, 16 require an iOS 17+ simulator. If `xcrun simctl list devices` doesn't show "iPhone 15", install one via Xcode → Settings → Components.

5. **Bundle Identifier**: Tasks assume `io.awairo.AwaIro`. If user chose differently in Task 11, update Task 16 Step 2's `xcrun simctl launch` call accordingly.

6. **Plan scope ends at Task 17**: The Phase 1 retro DISCUSSION (filling in `phase1-retro.md`, deciding agent additions) is out of scope for this plan — it's a separate orchestrator+user activity after Task 17.

7. **Phase 1 should yield ~17-20 commits**. Each is small and reversible. Push to PR after Task 16 (HITL).
