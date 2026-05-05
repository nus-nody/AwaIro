# Phase 3 — Sprint 2 Develop（現像）Implementation Plan (iOS)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 24時間後に「現像」される泡たちのギャラリー、タップで泡が割れて写真とメモが見える詳細画面、システム連動のダーク/ライトモードと6色のカラーパレットを iOS ネイティブ（SwiftUI + Swift Concurrency）で実装する。

**Architecture:** 既存 `AppRoute` を `.gallery` / `.photoDetail(UUID)` で拡張し `NavigationStack` で遷移。時刻は Domain 層の `Clock` protocol を UseCase init で注入してテスタビリティ確保。テーマは `UserDefaults` で永続化し、`SkyTheme` 値型を SwiftUI `EnvironmentKey` で全画面に提供。詳細画面の前後遷移は `TabView(.page)`。

**Tech Stack:** SwiftUI / `@Observable` / Swift Concurrency / GRDB.swift / Swift Testing / swift-snapshot-testing。新規外部依存なし（`UserDefaults` で十分）。

**Spec:** [docs/superpowers/specs/2026-05-02-sprint-2-develop-design.md](../specs/2026-05-02-sprint-2-develop-design.md) — KMP 前提のものを iOS に翻訳

**Phase scope（Concept Guardrail）:** G2 (翌日まで非表示) を usecase / Photo モデルで強制。G3 (数字なし) を全 snapshot テストで照合。

**Out of scope（Phase 4+ 持ち越し）:**
- 泡が割れる pop animation（spec §3.6）— Phase 3 では float animation のみ実装。pop は visual polish として後送り
- スクロール parallax（spec §3.4 後半）— LazyVStack の素直な縦並びのみ
- Skia 級の薄膜干渉色 / カスタム Shape — SwiftUI 標準の `Circle + RadialGradient` 実装で済ませる

---

## Pre-flight — ベースライン確認

### Task 0: Baseline 緑

**Files:** なし

- [ ] **Step 1: 現在のブランチで `make verify` を実行**

```bash
make verify
```

Expected: `BUILD SUCCESSFUL` / 全テスト緑 / lint 緑。

失敗する場合は Phase 2 マージ後の差分が原因の可能性。先に解消する。

- [ ] **Step 2: iOS Simulator で App ビルドが通ることを確認**

```bash
xcodebuild build -project App/AwaIro.xcodeproj -scheme AwaIro \
  -destination 'platform=iOS Simulator,name=iPhone 16 (AwaIro)'
```

Expected: `BUILD SUCCESSFUL`

- [ ] **Step 3: 確認済みベースで Phase 3 開始**

ここから先の Task は全て緑のベースから始まる前提。途中で失敗したら必ず原因を切り分けてから次へ進む。

---

## Domain Layer (Pure Swift, no iOS imports)

### Task 1: Clock protocol + SystemClock

**Files:**
- Create: `packages/AwaIroDomain/Sources/AwaIroDomain/Time/Clock.swift`
- Create: `packages/AwaIroDomain/Tests/AwaIroDomainTests/ClockTests.swift`

- [ ] **Step 1: テストを書く**

`packages/AwaIroDomain/Tests/AwaIroDomainTests/ClockTests.swift`:

```swift
import Foundation
import Testing

@testable import AwaIroDomain

@Suite("Clock")
struct ClockTests {
  @Test("SystemClock returns Date close to Date()")
  func systemClockNow() {
    let clock = SystemClock()
    let before = Date()
    let now = clock.now()
    let after = Date()
    #expect(now >= before && now <= after)
  }

  @Test("FixedClock returns the configured instant repeatedly")
  func fixedClockIsConstant() {
    let fixed = Date(timeIntervalSince1970: 1_730_000_000)
    let clock = FixedClock(instant: fixed)
    #expect(clock.now() == fixed)
    #expect(clock.now() == fixed)
  }
}
```

- [ ] **Step 2: テストが fail することを確認**

```bash
swift test --package-path packages/AwaIroDomain --filter ClockTests
```

Expected: コンパイルエラー（`Clock` 型が無い）。

- [ ] **Step 3: Clock protocol と impl を実装**

`packages/AwaIroDomain/Sources/AwaIroDomain/Time/Clock.swift`:

```swift
import Foundation

/// A pluggable source of the current instant.
/// Inject via UseCase init to keep time-dependent logic deterministic in tests.
public protocol Clock: Sendable {
  func now() -> Date
}

/// Production clock — returns `Date()`.
public struct SystemClock: Clock {
  public init() {}
  public func now() -> Date { Date() }
}

/// Test double — returns the same instant every call.
public struct FixedClock: Clock {
  private let instant: Date
  public init(instant: Date) { self.instant = instant }
  public func now() -> Date { instant }
}
```

- [ ] **Step 4: テスト緑を確認**

```bash
swift test --package-path packages/AwaIroDomain --filter ClockTests
```

Expected: `Test run with 2 tests passed`

- [ ] **Step 5: コミット**

```bash
git add packages/AwaIroDomain/Sources/AwaIroDomain/Time/Clock.swift \
        packages/AwaIroDomain/Tests/AwaIroDomainTests/ClockTests.swift
git commit -m "feat(domain): add Clock protocol with SystemClock + FixedClock for time injection"
```

---

### Task 2: Photo に developedAt / isDeveloped / remainingUntilDeveloped を追加

**Files:**
- Modify: `packages/AwaIroDomain/Sources/AwaIroDomain/Models/Photo.swift`
- Modify: `packages/AwaIroDomain/Tests/AwaIroDomainTests/PhotoTests.swift`

- [ ] **Step 1: Photo の追加メソッドのテストを書く（既存テスト末尾に追加）**

`packages/AwaIroDomain/Tests/AwaIroDomainTests/PhotoTests.swift` を以下に置き換え:

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
    let dev = now.addingTimeInterval(86400)
    let url = URL(fileURLWithPath: "/tmp/x.jpg")
    let a = Photo(id: id, takenAt: now, developedAt: dev, fileURL: url, memo: "morning walk")
    let b = Photo(id: id, takenAt: now, developedAt: dev, fileURL: url, memo: "morning walk")
    #expect(a == b)
    #expect(a.hashValue == b.hashValue)
  }

  @Test("memo is optional")
  func optionalMemo() {
    let now = Date()
    let p = Photo(
      id: UUID(), takenAt: now, developedAt: now.addingTimeInterval(86400),
      fileURL: URL(fileURLWithPath: "/x.jpg"), memo: nil)
    #expect(p.memo == nil)
  }

  @Test("Codable round-trip preserves all fields")
  func codableRoundTrip() throws {
    let taken = Date(timeIntervalSince1970: 1_730_000_000)
    let original = Photo(
      id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
      takenAt: taken,
      developedAt: taken.addingTimeInterval(86400),
      fileURL: URL(fileURLWithPath: "/tmp/x.jpg"),
      memo: "nuance"
    )
    let data = try JSONEncoder().encode(original)
    let decoded = try JSONDecoder().decode(Photo.self, from: data)
    #expect(decoded == original)
  }

  // MARK: - G2 guardrail (翌日まで非表示)

  @Test("isDeveloped returns true exactly at developedAt boundary")
  func isDevelopedAtBoundary() {
    let taken = Date(timeIntervalSince1970: 1_730_000_000)
    let dev = taken.addingTimeInterval(86400)
    let p = Photo(
      id: UUID(), takenAt: taken, developedAt: dev,
      fileURL: URL(fileURLWithPath: "/x.jpg"), memo: nil)
    #expect(p.isDeveloped(now: dev))
  }

  @Test("isDeveloped returns false 1 second before developedAt")
  func isDevelopedJustBefore() {
    let taken = Date(timeIntervalSince1970: 1_730_000_000)
    let dev = taken.addingTimeInterval(86400)
    let just = dev.addingTimeInterval(-1)
    let p = Photo(
      id: UUID(), takenAt: taken, developedAt: dev,
      fileURL: URL(fileURLWithPath: "/x.jpg"), memo: nil)
    #expect(!p.isDeveloped(now: just))
  }

  @Test("remainingUntilDeveloped returns zero when already developed")
  func remainingZeroWhenDeveloped() {
    let taken = Date(timeIntervalSince1970: 1_730_000_000)
    let dev = taken.addingTimeInterval(86400)
    let later = dev.addingTimeInterval(3600)
    let p = Photo(
      id: UUID(), takenAt: taken, developedAt: dev,
      fileURL: URL(fileURLWithPath: "/x.jpg"), memo: nil)
    #expect(p.remainingUntilDeveloped(now: later) == 0)
  }

  @Test("remainingUntilDeveloped returns correct interval when not developed")
  func remainingWhenNotDeveloped() {
    let taken = Date(timeIntervalSince1970: 1_730_000_000)
    let dev = taken.addingTimeInterval(86400)
    let mid = taken.addingTimeInterval(43200)  // halfway
    let p = Photo(
      id: UUID(), takenAt: taken, developedAt: dev,
      fileURL: URL(fileURLWithPath: "/x.jpg"), memo: nil)
    #expect(p.remainingUntilDeveloped(now: mid) == 43200)
  }
}
```

- [ ] **Step 2: テストが fail することを確認**

```bash
swift test --package-path packages/AwaIroDomain --filter PhotoTests
```

Expected: コンパイルエラー（`developedAt` が無い、`isDeveloped` が無い）。

- [ ] **Step 3: Photo モデルを拡張**

`packages/AwaIroDomain/Sources/AwaIroDomain/Models/Photo.swift`:

```swift
import Foundation

public struct Photo: Hashable, Codable, Sendable {
  public let id: UUID
  public let takenAt: Date
  public let developedAt: Date
  public let fileURL: URL
  public let memo: String?

  public init(id: UUID, takenAt: Date, developedAt: Date, fileURL: URL, memo: String?) {
    self.id = id
    self.takenAt = takenAt
    self.developedAt = developedAt
    self.fileURL = fileURL
    self.memo = memo
  }

  /// G2 guardrail: a photo is "developed" only at or after `developedAt`.
  public func isDeveloped(now: Date) -> Bool {
    now >= developedAt
  }

  /// Seconds until developed. Zero if already developed.
  public func remainingUntilDeveloped(now: Date) -> TimeInterval {
    isDeveloped(now: now) ? 0 : developedAt.timeIntervalSince(now)
  }
}
```

- [ ] **Step 4: 既存呼び出し箇所のコンパイルエラーを修正**

既存コードで `Photo(id:takenAt:fileURL:memo:)` を呼んでいる箇所がある（`PhotoRepositoryImpl`, `PhotoTests`, `RecordPhotoUseCase`, `RecordPhotoUseCaseTests`, `HomeScreenSnapshotTests`, etc）。これらは Task 6 / 8 / 17 で順に直すが、ここではまず **Domain Tests のみ緑にする**。

```bash
swift test --package-path packages/AwaIroDomain --filter PhotoTests
```

Expected: `7 tests passed`（`equality`, `optionalMemo`, `codableRoundTrip`, `isDevelopedAtBoundary`, `isDevelopedJustBefore`, `remainingZeroWhenDeveloped`, `remainingWhenNotDeveloped`）

`packages/AwaIroDomain` はまだ他テスト（RecordPhotoUseCaseTests, GetTodayPhotoUseCaseTests）でコンパイルが通らない可能性あり。Task 6 で usecase 側を直して再度緑にする。

- [ ] **Step 5: コミット**

```bash
git add packages/AwaIroDomain/Sources/AwaIroDomain/Models/Photo.swift \
        packages/AwaIroDomain/Tests/AwaIroDomainTests/PhotoTests.swift
git commit -m "feat(domain): add developedAt + isDeveloped/remainingUntilDeveloped for G2 guardrail"
```

---

### Task 3: PhotoRepository protocol を拡張

**Files:**
- Modify: `packages/AwaIroDomain/Sources/AwaIroDomain/Repositories/PhotoRepository.swift`

- [ ] **Step 1: PhotoRepository に 3 メソッドを追加**

```swift
import Foundation

public protocol PhotoRepository: Sendable {
  /// Fetches the photo recorded on the same calendar day (device local) as `now`.
  /// Returns nil if no photo recorded today.
  func todayPhoto(now: Date) async throws -> Photo?

  /// Inserts a new photo. Assumes caller has already enforced "1日1枚" guardrail (G1) at use case level.
  func insert(_ photo: Photo) async throws

  /// Returns all photos ordered by `takenAt` descending (newest first).
  func findAllOrderByTakenAtDesc() async throws -> [Photo]

  /// Returns the photo with the given id, or nil if not found.
  func findById(_ id: UUID) async throws -> Photo?

  /// Updates the memo for the photo with the given id. No-op if id not found.
  func updateMemo(id: UUID, memo: String?) async throws
}
```

- [ ] **Step 2: コンパイルが通ることを確認（domain のみ）**

```bash
swift build --package-path packages/AwaIroDomain
```

Expected: `Build complete!`（warning として PhotoRepositoryImpl が unconformant な可能性 — protocol はまだ pure Domain 内）。

- [ ] **Step 3: コミット**

```bash
git add packages/AwaIroDomain/Sources/AwaIroDomain/Repositories/PhotoRepository.swift
git commit -m "feat(domain): extend PhotoRepository with findAll/findById/updateMemo"
```

---

### Task 4: SkyPalette + ThemeMode 値型

**Files:**
- Create: `packages/AwaIroDomain/Sources/AwaIroDomain/Models/SkyPalette.swift`
- Create: `packages/AwaIroDomain/Sources/AwaIroDomain/Models/ThemeMode.swift`
- Create: `packages/AwaIroDomain/Tests/AwaIroDomainTests/SkyPaletteTests.swift`

- [ ] **Step 1: SkyPalette のテストを書く**

`packages/AwaIroDomain/Tests/AwaIroDomainTests/SkyPaletteTests.swift`:

```swift
import Testing

@testable import AwaIroDomain

@Suite("SkyPalette + ThemeMode")
struct SkyPaletteTests {
  @Test("SkyPalette has all six expected cases")
  func sixPalettes() {
    let allCases = SkyPalette.allCases
    #expect(allCases.count == 6)
    #expect(allCases.contains(.nightSky))
    #expect(allCases.contains(.mist))
    #expect(allCases.contains(.dusk))
    #expect(allCases.contains(.komorebi))
    #expect(allCases.contains(.akatsuki))
    #expect(allCases.contains(.silverFog))
  }

  @Test("SkyPalette rawValue stable for persistence")
  func stableRawValue() {
    #expect(SkyPalette.nightSky.rawValue == "night_sky")
    #expect(SkyPalette.mist.rawValue == "mist")
    #expect(SkyPalette.dusk.rawValue == "dusk")
    #expect(SkyPalette.komorebi.rawValue == "komorebi")
    #expect(SkyPalette.akatsuki.rawValue == "akatsuki")
    #expect(SkyPalette.silverFog.rawValue == "silver_fog")
  }

  @Test("SkyPalette.from(rawValue:) returns nil for unknown")
  func fromUnknown() {
    #expect(SkyPalette(rawValue: "unknown") == nil)
  }

  @Test("ThemeMode has system/dark/light")
  func threeModes() {
    #expect(ThemeMode.allCases.count == 3)
    #expect(ThemeMode.system.rawValue == "system")
    #expect(ThemeMode.dark.rawValue == "dark")
    #expect(ThemeMode.light.rawValue == "light")
  }
}
```

- [ ] **Step 2: テストが fail することを確認**

```bash
swift test --package-path packages/AwaIroDomain --filter SkyPaletteTests
```

Expected: コンパイルエラー。

- [ ] **Step 3: SkyPalette と ThemeMode を実装**

`packages/AwaIroDomain/Sources/AwaIroDomain/Models/SkyPalette.swift`:

```swift
import Foundation

/// Six selectable color palettes for the gallery sky.
/// Stored via `rawValue`, so do not change values without a migration.
public enum SkyPalette: String, CaseIterable, Hashable, Codable, Sendable {
  case nightSky = "night_sky"
  case mist = "mist"
  case dusk = "dusk"
  case komorebi = "komorebi"
  case akatsuki = "akatsuki"
  case silverFog = "silver_fog"

  public var displayName: String {
    switch self {
    case .nightSky: "夜空"
    case .mist: "霧海"
    case .dusk: "夕暮れ"
    case .komorebi: "木漏れ日"
    case .akatsuki: "暁"
    case .silverFog: "銀霧"
    }
  }
}
```

`packages/AwaIroDomain/Sources/AwaIroDomain/Models/ThemeMode.swift`:

```swift
import Foundation

public enum ThemeMode: String, CaseIterable, Hashable, Codable, Sendable {
  case system = "system"
  case dark = "dark"
  case light = "light"
}
```

- [ ] **Step 4: テスト緑を確認**

```bash
swift test --package-path packages/AwaIroDomain --filter SkyPaletteTests
```

Expected: `4 tests passed`

- [ ] **Step 5: コミット**

```bash
git add packages/AwaIroDomain/Sources/AwaIroDomain/Models/SkyPalette.swift \
        packages/AwaIroDomain/Sources/AwaIroDomain/Models/ThemeMode.swift \
        packages/AwaIroDomain/Tests/AwaIroDomainTests/SkyPaletteTests.swift
git commit -m "feat(domain): add SkyPalette + ThemeMode value types"
```

---

### Task 5: ThemeRepository protocol

**Files:**
- Create: `packages/AwaIroDomain/Sources/AwaIroDomain/Repositories/ThemeRepository.swift`

- [ ] **Step 1: ThemeRepository protocol を実装（テスト不要 — 純粋な protocol 宣言）**

`packages/AwaIroDomain/Sources/AwaIroDomain/Repositories/ThemeRepository.swift`:

```swift
import Foundation

/// Persists the user's theme preferences (palette + mode).
/// Thread-safe implementations are required to be `Sendable`.
public protocol ThemeRepository: Sendable {
  func getPalette() async -> SkyPalette
  func setPalette(_ palette: SkyPalette) async
  func getMode() async -> ThemeMode
  func setMode(_ mode: ThemeMode) async
}
```

- [ ] **Step 2: コンパイル確認**

```bash
swift build --package-path packages/AwaIroDomain
```

- [ ] **Step 3: コミット**

```bash
git add packages/AwaIroDomain/Sources/AwaIroDomain/Repositories/ThemeRepository.swift
git commit -m "feat(domain): add ThemeRepository protocol"
```

---

### Task 6: RecordPhotoUseCase に developedAt = takenAt + 24h を追加 + 既存テスト直し

**Files:**
- Modify: `packages/AwaIroDomain/Sources/AwaIroDomain/UseCases/RecordPhotoUseCase.swift`
- Modify: `packages/AwaIroDomain/Tests/AwaIroDomainTests/RecordPhotoUseCaseTests.swift`

- [ ] **Step 1: テスト末尾に developedAt 検証を追加**

`packages/AwaIroDomain/Tests/AwaIroDomainTests/RecordPhotoUseCaseTests.swift` の `@Suite` 内に追加:

```swift
@Test("sets developedAt to takenAt + 24 hours")
func setsDevelopedAt() async throws {
  let repo = FakePhotoRepository()
  let usecase = RecordPhotoUseCase(repository: repo)
  let now = Date(timeIntervalSince1970: 1_730_000_000)
  let url = URL(fileURLWithPath: "/tmp/x.jpg")

  let saved = try await usecase.execute(fileURL: url, takenAt: now, memo: nil)

  #expect(saved.developedAt == now.addingTimeInterval(86400))
}
```

既存テストの `Photo(id:takenAt:fileURL:memo:)` 呼び出し（`FakePhotoRepository.todayPhoto`/`insert` 内には現状なし）と Photo 直接作成箇所（`PhotoTests` のみ — 既に Task 2 で更新済み）以外、`RecordPhotoUseCaseTests` は API 変更なし（`execute(fileURL:takenAt:memo:)` のシグネチャ不変）。

- [ ] **Step 2: テストが fail することを確認**

```bash
swift test --package-path packages/AwaIroDomain --filter RecordPhotoUseCaseTests
```

Expected: 既存 5 件 pass + `setsDevelopedAt` が fail（または compile error）。

- [ ] **Step 3: RecordPhotoUseCase を更新**

`packages/AwaIroDomain/Sources/AwaIroDomain/UseCases/RecordPhotoUseCase.swift`:

```swift
import Foundation

public struct RecordPhotoUseCase: Sendable {
  private static let developWindow: TimeInterval = 86400  // 24h

  private let repository: any PhotoRepository

  public init(repository: any PhotoRepository) {
    self.repository = repository
  }

  /// Inserts a new photo if no photo exists for today's calendar day.
  /// G1 guardrail: throws .alreadyRecordedToday if a photo already exists.
  /// Sets developedAt to takenAt + 24h (G2 guardrail).
  /// Repository failures are wrapped in .repositoryFailure(message:).
  public func execute(fileURL: URL, takenAt: Date, memo: String?) async throws -> Photo {
    if try await repository.todayPhoto(now: takenAt) != nil {
      throw RecordPhotoError.alreadyRecordedToday
    }

    let photo = Photo(
      id: UUID(),
      takenAt: takenAt,
      developedAt: takenAt.addingTimeInterval(Self.developWindow),
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

- [ ] **Step 4: FakePhotoRepository が PhotoRepository protocol に conform するよう更新**

`RecordPhotoUseCaseTests.swift` の `FakePhotoRepository`:

```swift
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
    if let insertError {
      throw RecordPhotoError.repositoryFailure(message: String(describing: insertError))
    }
    inserted.append(photo)
  }

  func findAllOrderByTakenAtDesc() async throws -> [Photo] {
    inserted.sorted { $0.takenAt > $1.takenAt }
  }

  func findById(_ id: UUID) async throws -> Photo? {
    inserted.first { $0.id == id }
  }

  func updateMemo(id: UUID, memo: String?) async throws {
    if let idx = inserted.firstIndex(where: { $0.id == id }) {
      let p = inserted[idx]
      inserted[idx] = Photo(
        id: p.id, takenAt: p.takenAt, developedAt: p.developedAt,
        fileURL: p.fileURL, memo: memo)
    }
  }
}
```

- [ ] **Step 5: 全 Domain テスト緑を確認**

```bash
swift test --package-path packages/AwaIroDomain
```

Expected: 全 suite pass（Photo / Clock / SkyPalette / RecordPhotoUseCase / GetTodayPhotoUseCase）。

`GetTodayPhotoUseCaseTests` は Photo 直接作成しないので変更不要のはず。コンパイルエラーが出たら同様に Photo init を更新。

- [ ] **Step 6: コミット**

```bash
git add packages/AwaIroDomain/Sources/AwaIroDomain/UseCases/RecordPhotoUseCase.swift \
        packages/AwaIroDomain/Tests/AwaIroDomainTests/RecordPhotoUseCaseTests.swift
git commit -m "feat(domain): RecordPhotoUseCase sets developedAt = takenAt + 24h"
```

---

### Task 7: DevelopPhotoUseCase

**Files:**
- Create: `packages/AwaIroDomain/Sources/AwaIroDomain/UseCases/DevelopPhotoUseCase.swift`
- Create: `packages/AwaIroDomain/Tests/AwaIroDomainTests/DevelopPhotoUseCaseTests.swift`

- [ ] **Step 1: テストを書く**

`packages/AwaIroDomain/Tests/AwaIroDomainTests/DevelopPhotoUseCaseTests.swift`:

```swift
import Foundation
import Testing

@testable import AwaIroDomain

@Suite("DevelopPhotoUseCase — G2 (翌日まで非表示)")
struct DevelopPhotoUseCaseTests {

  private func makePhoto(taken: Date, id: String = "11111111-1111-1111-1111-111111111111") -> Photo {
    Photo(
      id: UUID(uuidString: id)!,
      takenAt: taken,
      developedAt: taken.addingTimeInterval(86400),
      fileURL: URL(fileURLWithPath: "/tmp/\(id).jpg"),
      memo: nil
    )
  }

  @Test("returns all photos ordered by takenAt desc")
  func returnsAllSorted() async throws {
    let cal = Calendar.current
    let day1 = cal.date(from: DateComponents(year: 2026, month: 5, day: 1))!
    let day2 = cal.date(from: DateComponents(year: 2026, month: 5, day: 2))!
    let day3 = cal.date(from: DateComponents(year: 2026, month: 5, day: 3))!

    let repo = FakeRepo()
    try await repo.insert(makePhoto(taken: day2, id: "22222222-2222-2222-2222-222222222222"))
    try await repo.insert(makePhoto(taken: day1, id: "11111111-1111-1111-1111-111111111111"))
    try await repo.insert(makePhoto(taken: day3, id: "33333333-3333-3333-3333-333333333333"))

    let usecase = DevelopPhotoUseCase(repository: repo, clock: FixedClock(instant: day3))
    let photos = try await usecase.execute()

    #expect(photos.count == 3)
    #expect(photos[0].takenAt == day3)
    #expect(photos[1].takenAt == day2)
    #expect(photos[2].takenAt == day1)
  }

  @Test("photo taken 23h ago is NOT developed (G2)")
  func notDevelopedWithin24h() async throws {
    let now = Date(timeIntervalSince1970: 1_730_000_000)
    let taken = now.addingTimeInterval(-23 * 3600)

    let repo = FakeRepo()
    try await repo.insert(makePhoto(taken: taken))

    let usecase = DevelopPhotoUseCase(repository: repo, clock: FixedClock(instant: now))
    let photos = try await usecase.execute()

    #expect(photos.count == 1)
    #expect(!photos[0].isDeveloped(now: now))
  }

  @Test("photo taken 25h ago IS developed (G2)")
  func developedAfter24h() async throws {
    let now = Date(timeIntervalSince1970: 1_730_000_000)
    let taken = now.addingTimeInterval(-25 * 3600)

    let repo = FakeRepo()
    try await repo.insert(makePhoto(taken: taken))

    let usecase = DevelopPhotoUseCase(repository: repo, clock: FixedClock(instant: now))
    let photos = try await usecase.execute()

    #expect(photos.count == 1)
    #expect(photos[0].isDeveloped(now: now))
  }

  @Test("empty repository returns empty list")
  func emptyReturnsEmpty() async throws {
    let repo = FakeRepo()
    let usecase = DevelopPhotoUseCase(repository: repo, clock: SystemClock())
    let photos = try await usecase.execute()
    #expect(photos.isEmpty)
  }
}

private final class FakeRepo: PhotoRepository, @unchecked Sendable {
  private var photos: [Photo] = []

  func todayPhoto(now: Date) async throws -> Photo? { nil }
  func insert(_ photo: Photo) async throws { photos.append(photo) }
  func findAllOrderByTakenAtDesc() async throws -> [Photo] {
    photos.sorted { $0.takenAt > $1.takenAt }
  }
  func findById(_ id: UUID) async throws -> Photo? { photos.first { $0.id == id } }
  func updateMemo(id: UUID, memo: String?) async throws {}
}
```

- [ ] **Step 2: テストが fail することを確認**

```bash
swift test --package-path packages/AwaIroDomain --filter DevelopPhotoUseCaseTests
```

Expected: コンパイルエラー（`DevelopPhotoUseCase` が無い）。

- [ ] **Step 3: DevelopPhotoUseCase を実装**

`packages/AwaIroDomain/Sources/AwaIroDomain/UseCases/DevelopPhotoUseCase.swift`:

```swift
import Foundation

public struct DevelopPhotoUseCase: Sendable {
  private let repository: any PhotoRepository
  private let clock: any Clock

  public init(repository: any PhotoRepository, clock: any Clock) {
    self.repository = repository
    self.clock = clock
  }

  /// Returns all photos ordered by takenAt descending (newest first).
  /// Callers determine `isDeveloped` per photo using `Photo.isDeveloped(now:)` —
  /// the use case does not filter, since the gallery shows undeveloped bubbles too
  /// (just opaque, with "あと○時間" copy).
  public func execute() async throws -> [Photo] {
    try await repository.findAllOrderByTakenAtDesc()
  }
}
```

> Note: `clock` は現状の `execute()` では使わないが、将来「N 時間以内に現像予定の写真だけ返す」等の filter を入れる時のために注入しておく。今は遊び。**実は不要なら削除してよい** — 削除する場合は test の `FixedClock` 引数も外す。シンプル原則 (YAGNI) を優先するなら `clock` 引数を消す。

→ **YAGNI に従い `clock` を一旦削除**:

```swift
import Foundation

public struct DevelopPhotoUseCase: Sendable {
  private let repository: any PhotoRepository

  public init(repository: any PhotoRepository) {
    self.repository = repository
  }

  /// Returns all photos ordered by takenAt descending (newest first).
  /// Callers determine `isDeveloped` per photo using `Photo.isDeveloped(now:)`.
  public func execute() async throws -> [Photo] {
    try await repository.findAllOrderByTakenAtDesc()
  }
}
```

そしてテスト側の `DevelopPhotoUseCase(repository: repo, clock: ...)` を `DevelopPhotoUseCase(repository: repo)` に修正。

- [ ] **Step 4: テスト緑を確認**

```bash
swift test --package-path packages/AwaIroDomain --filter DevelopPhotoUseCaseTests
```

Expected: `4 tests passed`

- [ ] **Step 5: コミット**

```bash
git add packages/AwaIroDomain/Sources/AwaIroDomain/UseCases/DevelopPhotoUseCase.swift \
        packages/AwaIroDomain/Tests/AwaIroDomainTests/DevelopPhotoUseCaseTests.swift
git commit -m "feat(domain): add DevelopPhotoUseCase returning all photos sorted by takenAt desc"
```

---

### Task 8: UpdateMemoUseCase

**Files:**
- Create: `packages/AwaIroDomain/Sources/AwaIroDomain/UseCases/UpdateMemoUseCase.swift`
- Create: `packages/AwaIroDomain/Tests/AwaIroDomainTests/UpdateMemoUseCaseTests.swift`

- [ ] **Step 1: テストを書く**

`packages/AwaIroDomain/Tests/AwaIroDomainTests/UpdateMemoUseCaseTests.swift`:

```swift
import Foundation
import Testing

@testable import AwaIroDomain

@Suite("UpdateMemoUseCase")
struct UpdateMemoUseCaseTests {

  @Test("updates memo on existing photo")
  func updatesExisting() async throws {
    let id = UUID()
    let now = Date(timeIntervalSince1970: 1_730_000_000)
    let p = Photo(
      id: id, takenAt: now, developedAt: now.addingTimeInterval(86400),
      fileURL: URL(fileURLWithPath: "/x"), memo: "old")

    let repo = FakeRepo(seed: [p])
    let usecase = UpdateMemoUseCase(repository: repo)

    try await usecase.execute(id: id, memo: "new")

    let updated = try await repo.findById(id)
    #expect(updated?.memo == "new")
  }

  @Test("nil memo is allowed (clearing)")
  func clearMemo() async throws {
    let id = UUID()
    let now = Date(timeIntervalSince1970: 1_730_000_000)
    let p = Photo(
      id: id, takenAt: now, developedAt: now.addingTimeInterval(86400),
      fileURL: URL(fileURLWithPath: "/x"), memo: "old")

    let repo = FakeRepo(seed: [p])
    let usecase = UpdateMemoUseCase(repository: repo)

    try await usecase.execute(id: id, memo: nil)

    let updated = try await repo.findById(id)
    #expect(updated?.memo == nil)
  }

  @Test("missing id is no-op (does not throw)")
  func missingIdNoop() async throws {
    let repo = FakeRepo(seed: [])
    let usecase = UpdateMemoUseCase(repository: repo)
    try await usecase.execute(id: UUID(), memo: "x")
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
```

- [ ] **Step 2: テストが fail することを確認**

```bash
swift test --package-path packages/AwaIroDomain --filter UpdateMemoUseCaseTests
```

Expected: コンパイルエラー。

- [ ] **Step 3: UpdateMemoUseCase を実装**

`packages/AwaIroDomain/Sources/AwaIroDomain/UseCases/UpdateMemoUseCase.swift`:

```swift
import Foundation

public struct UpdateMemoUseCase: Sendable {
  private let repository: any PhotoRepository

  public init(repository: any PhotoRepository) {
    self.repository = repository
  }

  public func execute(id: UUID, memo: String?) async throws {
    try await repository.updateMemo(id: id, memo: memo)
  }
}
```

- [ ] **Step 4: テスト緑を確認**

```bash
swift test --package-path packages/AwaIroDomain --filter UpdateMemoUseCaseTests
```

Expected: `3 tests passed`

- [ ] **Step 5: 全 Domain テスト緑を確認**

```bash
swift test --package-path packages/AwaIroDomain
```

- [ ] **Step 6: コミット**

```bash
git add packages/AwaIroDomain/Sources/AwaIroDomain/UseCases/UpdateMemoUseCase.swift \
        packages/AwaIroDomain/Tests/AwaIroDomainTests/UpdateMemoUseCaseTests.swift
git commit -m "feat(domain): add UpdateMemoUseCase"
```

---

## Data Layer

### Task 9: Migration v2 — developed_at column 追加

> **HITL gate:** DB スキーマ変更は HITL 必須（[gate-matrix](../../harness/gate-matrix.md)）。実装着手前にユーザーに「v2 migration を進めてよいか」を承認取得すること。

**Files:**
- Modify: `packages/AwaIroData/Sources/AwaIroData/Database/Migrations.swift`
- Modify: `packages/AwaIroData/Tests/AwaIroDataTests/MigrationsTests.swift`

- [ ] **Step 1: ユーザーに HITL 承認を取得**

「Phase 3 のスキーマ変更（v2: developed_at column 追加 + 既存行 backfill）を始めて良いか？」と確認。承認を得たら次へ。

- [ ] **Step 2: テストを追加（Migrations v2）**

`packages/AwaIroData/Tests/AwaIroDataTests/MigrationsTests.swift` の末尾に追加（既存テストの形式に従う）:

```swift
@Test("v2 adds developed_at column with backfill (taken_at + 86400)")
func v2AddsDevelopedAt() throws {
  let queue = try DatabaseFactory.makeInMemoryQueue()

  // Manually apply v1 only, insert old-style row, then migrate to v2.
  try queue.write { db in
    try db.execute(sql: """
      CREATE TABLE photos (
        id TEXT PRIMARY KEY,
        taken_at REAL NOT NULL,
        file_url TEXT NOT NULL,
        memo TEXT
      );
      """)
    try db.execute(sql: """
      INSERT INTO photos (id, taken_at, file_url, memo)
      VALUES ('11111111-1111-1111-1111-111111111111', 1730000000, '/tmp/x.jpg', 'm')
      """)
  }

  // Apply v2.
  try Migrations.applyV2Only(to: queue)

  try queue.read { db in
    let row = try Row.fetchOne(db, sql: "SELECT taken_at, developed_at FROM photos WHERE id = '11111111-1111-1111-1111-111111111111'")!
    let taken: Double = row["taken_at"]
    let developed: Double = row["developed_at"]
    #expect(developed == taken + 86400)
  }
}
```

> Note: `applyV2Only` は test 用ヘルパ。本番は `applyAll`。

- [ ] **Step 3: テストが fail することを確認**

```bash
swift test --package-path packages/AwaIroData --filter MigrationsTests
```

Expected: コンパイルエラー（`applyV2Only` が無い）。

- [ ] **Step 4: Migrations v2 を実装**

`packages/AwaIroData/Sources/AwaIroData/Database/Migrations.swift`:

```swift
import GRDB

public enum Migrations {
  /// Apply all migrations in order. Idempotent.
  public static func applyAll(to writer: any DatabaseWriter) throws {
    var migrator = DatabaseMigrator()
    registerV1(in: &migrator)
    registerV2(in: &migrator)
    try migrator.migrate(writer)
  }

  /// Test-only helper: apply only v2 (assumes v1 schema exists).
  public static func applyV2Only(to writer: any DatabaseWriter) throws {
    var migrator = DatabaseMigrator()
    // Mark v1 as already applied so the migrator skips it.
    migrator.registerMigration("v1_create_photos") { _ in
      // already applied externally
    }
    registerV2(in: &migrator)
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

  private static func registerV2(in migrator: inout DatabaseMigrator) {
    migrator.registerMigration("v2_add_developed_at") { db in
      // Add nullable column first to allow backfill.
      try db.alter(table: "photos") { t in
        t.add(column: "developed_at", .double)
      }
      // Backfill: developed_at = taken_at + 86400 (24h).
      try db.execute(sql: "UPDATE photos SET developed_at = taken_at + 86400 WHERE developed_at IS NULL")
      // GRDB does not support ALTER COLUMN ... NOT NULL on SQLite, so we leave it nullable
      // and rely on the application layer (PhotoRepositoryImpl.insert) to always set it.
    }
  }
}
```

- [ ] **Step 5: テスト緑を確認**

```bash
swift test --package-path packages/AwaIroData --filter MigrationsTests
```

Expected: `2 tests passed` (既存 v1 テスト + 新 v2 テスト)。`Row` import が必要なら test 先頭に `import GRDB` を追加。

- [ ] **Step 6: コミット**

```bash
git add packages/AwaIroData/Sources/AwaIroData/Database/Migrations.swift \
        packages/AwaIroData/Tests/AwaIroDataTests/MigrationsTests.swift
git commit -m "feat(data): migration v2 add developed_at column with takenAt+24h backfill"
```

---

### Task 10: PhotoRepositoryImpl を新 API + developed_at 対応に更新

**Files:**
- Modify: `packages/AwaIroData/Sources/AwaIroData/Repositories/PhotoRepositoryImpl.swift`
- Modify: `packages/AwaIroData/Tests/AwaIroDataTests/PhotoRepositoryImplTests.swift`

- [ ] **Step 1: テストを更新（既存 4 件 + 新規 4 件）**

`packages/AwaIroData/Tests/AwaIroDataTests/PhotoRepositoryImplTests.swift`:

```swift
import AwaIroDomain
import Foundation
import GRDB
import Testing

@testable import AwaIroData

@Suite("PhotoRepositoryImpl")
struct PhotoRepositoryImplTests {

  private func makeRepo() throws -> (PhotoRepositoryImpl, DatabaseQueue) {
    let queue = try DatabaseFactory.makeInMemoryQueue()
    return (PhotoRepositoryImpl(writer: queue), queue)
  }

  private func makePhoto(taken: Date, id: UUID = UUID(), memo: String? = nil) -> Photo {
    Photo(
      id: id, takenAt: taken, developedAt: taken.addingTimeInterval(86400),
      fileURL: URL(fileURLWithPath: "/tmp/\(id).jpg"), memo: memo)
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

    let photo = makePhoto(taken: baseDay, memo: "x")
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

    try await repo.insert(makePhoto(taken: yesterday))

    let result = try await repo.todayPhoto(now: today)
    #expect(result == nil)
  }

  @Test("insert then read preserves all fields including developedAt")
  func insertReadRoundTrip() async throws {
    let (repo, _) = try makeRepo()
    let now = Date(timeIntervalSince1970: 1_730_000_000)
    let original = makePhoto(taken: now, memo: "round-trip memo")
    try await repo.insert(original)
    let result = try await repo.todayPhoto(now: now)
    #expect(result == original)
    #expect(result?.developedAt == now.addingTimeInterval(86400))
  }

  // MARK: - New API for Phase 3

  @Test("findAllOrderByTakenAtDesc returns photos newest first")
  func findAllSorted() async throws {
    let (repo, _) = try makeRepo()
    let cal = Calendar.current
    let day1 = cal.date(from: DateComponents(year: 2026, month: 5, day: 1))!
    let day2 = cal.date(from: DateComponents(year: 2026, month: 5, day: 2))!
    let day3 = cal.date(from: DateComponents(year: 2026, month: 5, day: 3))!

    try await repo.insert(makePhoto(taken: day2))
    try await repo.insert(makePhoto(taken: day1))
    try await repo.insert(makePhoto(taken: day3))

    let all = try await repo.findAllOrderByTakenAtDesc()
    #expect(all.count == 3)
    #expect(all[0].takenAt == day3)
    #expect(all[1].takenAt == day2)
    #expect(all[2].takenAt == day1)
  }

  @Test("findAllOrderByTakenAtDesc returns empty when no photos")
  func findAllEmpty() async throws {
    let (repo, _) = try makeRepo()
    let all = try await repo.findAllOrderByTakenAtDesc()
    #expect(all.isEmpty)
  }

  @Test("findById returns the matching photo")
  func findByIdMatches() async throws {
    let (repo, _) = try makeRepo()
    let id = UUID()
    let now = Date(timeIntervalSince1970: 1_730_000_000)
    try await repo.insert(makePhoto(taken: now, id: id, memo: "find me"))

    let result = try await repo.findById(id)
    #expect(result?.id == id)
    #expect(result?.memo == "find me")
  }

  @Test("findById returns nil for unknown id")
  func findByIdMissing() async throws {
    let (repo, _) = try makeRepo()
    let result = try await repo.findById(UUID())
    #expect(result == nil)
  }

  @Test("updateMemo replaces memo for existing photo")
  func updateMemoReplaces() async throws {
    let (repo, _) = try makeRepo()
    let id = UUID()
    let now = Date(timeIntervalSince1970: 1_730_000_000)
    try await repo.insert(makePhoto(taken: now, id: id, memo: "old"))

    try await repo.updateMemo(id: id, memo: "new")

    let result = try await repo.findById(id)
    #expect(result?.memo == "new")
  }

  @Test("updateMemo nil clears memo")
  func updateMemoClears() async throws {
    let (repo, _) = try makeRepo()
    let id = UUID()
    let now = Date(timeIntervalSince1970: 1_730_000_000)
    try await repo.insert(makePhoto(taken: now, id: id, memo: "old"))

    try await repo.updateMemo(id: id, memo: nil)

    let result = try await repo.findById(id)
    #expect(result?.memo == nil)
  }

  @Test("updateMemo on missing id is a no-op")
  func updateMemoNoop() async throws {
    let (repo, _) = try makeRepo()
    try await repo.updateMemo(id: UUID(), memo: "x")  // should not throw
  }
}
```

- [ ] **Step 2: テストが fail することを確認**

```bash
swift test --package-path packages/AwaIroData --filter PhotoRepositoryImplTests
```

Expected: コンパイルエラー。

- [ ] **Step 3: PhotoRepositoryImpl を更新**

`packages/AwaIroData/Sources/AwaIroData/Repositories/PhotoRepositoryImpl.swift`:

```swift
import AwaIroDomain
import Foundation
import GRDB

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
              SELECT id, taken_at, developed_at, file_url, memo
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
              INSERT INTO photos (id, taken_at, developed_at, file_url, memo)
              VALUES (?, ?, ?, ?, ?)
          """,
        arguments: [
          photo.id.uuidString,
          photo.takenAt.timeIntervalSince1970,
          photo.developedAt.timeIntervalSince1970,
          photo.fileURL.absoluteString,
          photo.memo,
        ]
      )
    }
  }

  public func findAllOrderByTakenAtDesc() async throws -> [Photo] {
    try await writer.read { db in
      try Row.fetchAll(
        db,
        sql: """
              SELECT id, taken_at, developed_at, file_url, memo
              FROM photos
              ORDER BY taken_at DESC
          """
      ).map(Photo.init(row:))
    }
  }

  public func findById(_ id: UUID) async throws -> Photo? {
    try await writer.read { db in
      let row = try Row.fetchOne(
        db,
        sql: """
              SELECT id, taken_at, developed_at, file_url, memo
              FROM photos
              WHERE id = ?
              LIMIT 1
          """,
        arguments: [id.uuidString]
      )
      return row.map(Photo.init(row:))
    }
  }

  public func updateMemo(id: UUID, memo: String?) async throws {
    try await writer.write { db in
      try db.execute(
        sql: "UPDATE photos SET memo = ? WHERE id = ?",
        arguments: [memo, id.uuidString]
      )
    }
  }
}

extension Photo {
  fileprivate init(row: Row) {
    self.init(
      id: UUID(uuidString: row["id"])!,
      takenAt: Date(timeIntervalSince1970: row["taken_at"]),
      developedAt: Date(timeIntervalSince1970: row["developed_at"]),
      fileURL: URL(string: row["file_url"])!,
      memo: row["memo"]
    )
  }
}
```

- [ ] **Step 4: テスト緑を確認**

```bash
swift test --package-path packages/AwaIroData
```

Expected: 全 suite pass（Migrations + PhotoRepositoryImpl）。

- [ ] **Step 5: コミット**

```bash
git add packages/AwaIroData/Sources/AwaIroData/Repositories/PhotoRepositoryImpl.swift \
        packages/AwaIroData/Tests/AwaIroDataTests/PhotoRepositoryImplTests.swift
git commit -m "feat(data): PhotoRepositoryImpl supports developedAt + findAll/findById/updateMemo"
```

---

### Task 11: UserDefaultsThemeRepository

**Files:**
- Create: `packages/AwaIroData/Sources/AwaIroData/Repositories/UserDefaultsThemeRepository.swift`
- Create: `packages/AwaIroData/Tests/AwaIroDataTests/UserDefaultsThemeRepositoryTests.swift`

- [ ] **Step 1: テストを書く**

`packages/AwaIroData/Tests/AwaIroDataTests/UserDefaultsThemeRepositoryTests.swift`:

```swift
import AwaIroDomain
import Foundation
import Testing

@testable import AwaIroData

@Suite("UserDefaultsThemeRepository")
struct UserDefaultsThemeRepositoryTests {

  private func makeDefaults() -> UserDefaults {
    let suiteName = "test-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defaults.removePersistentDomain(forName: suiteName)
    return defaults
  }

  @Test("default palette is nightSky when nothing stored")
  func defaultPalette() async {
    let repo = UserDefaultsThemeRepository(defaults: makeDefaults())
    let palette = await repo.getPalette()
    #expect(palette == .nightSky)
  }

  @Test("default mode is system when nothing stored")
  func defaultMode() async {
    let repo = UserDefaultsThemeRepository(defaults: makeDefaults())
    let mode = await repo.getMode()
    #expect(mode == .system)
  }

  @Test("setPalette persists and is readable")
  func roundTripPalette() async {
    let repo = UserDefaultsThemeRepository(defaults: makeDefaults())
    await repo.setPalette(.dusk)
    let result = await repo.getPalette()
    #expect(result == .dusk)
  }

  @Test("setMode persists and is readable")
  func roundTripMode() async {
    let repo = UserDefaultsThemeRepository(defaults: makeDefaults())
    await repo.setMode(.dark)
    let result = await repo.getMode()
    #expect(result == .dark)
  }

  @Test("unknown stored palette falls back to default")
  func unknownPaletteFallback() async {
    let defaults = makeDefaults()
    defaults.set("garbage", forKey: "awairo.skyPalette")
    let repo = UserDefaultsThemeRepository(defaults: defaults)
    let palette = await repo.getPalette()
    #expect(palette == .nightSky)
  }
}
```

- [ ] **Step 2: テストが fail することを確認**

```bash
swift test --package-path packages/AwaIroData --filter UserDefaultsThemeRepositoryTests
```

Expected: コンパイルエラー。

- [ ] **Step 3: UserDefaultsThemeRepository を実装**

`packages/AwaIroData/Sources/AwaIroData/Repositories/UserDefaultsThemeRepository.swift`:

```swift
import AwaIroDomain
import Foundation

public final class UserDefaultsThemeRepository: ThemeRepository, @unchecked Sendable {
  private static let paletteKey = "awairo.skyPalette"
  private static let modeKey = "awairo.themeMode"

  private let defaults: UserDefaults

  public init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
  }

  public func getPalette() async -> SkyPalette {
    if let raw = defaults.string(forKey: Self.paletteKey),
       let palette = SkyPalette(rawValue: raw)
    {
      return palette
    }
    return .nightSky
  }

  public func setPalette(_ palette: SkyPalette) async {
    defaults.set(palette.rawValue, forKey: Self.paletteKey)
  }

  public func getMode() async -> ThemeMode {
    if let raw = defaults.string(forKey: Self.modeKey),
       let mode = ThemeMode(rawValue: raw)
    {
      return mode
    }
    return .system
  }

  public func setMode(_ mode: ThemeMode) async {
    defaults.set(mode.rawValue, forKey: Self.modeKey)
  }
}
```

- [ ] **Step 4: テスト緑を確認**

```bash
swift test --package-path packages/AwaIroData --filter UserDefaultsThemeRepositoryTests
```

Expected: `5 tests passed`

- [ ] **Step 5: コミット**

```bash
git add packages/AwaIroData/Sources/AwaIroData/Repositories/UserDefaultsThemeRepository.swift \
        packages/AwaIroData/Tests/AwaIroDataTests/UserDefaultsThemeRepositoryTests.swift
git commit -m "feat(data): UserDefaultsThemeRepository with palette + mode persistence"
```

---

## Presentation Layer — Theme Foundation

### Task 12: SkyTheme value type + SwiftUI EnvironmentKey

**Files:**
- Create: `packages/AwaIroPresentation/Sources/AwaIroPresentation/Theme/SkyTheme.swift`

- [ ] **Step 1: SkyTheme + EnvironmentKey を実装（テスト不要 — 純粋データ + SwiftUI binding）**

`packages/AwaIroPresentation/Sources/AwaIroPresentation/Theme/SkyTheme.swift`:

```swift
import AwaIroDomain
import SwiftUI

public struct SkyTheme: Equatable, Sendable {
  public let palette: SkyPalette
  public let mode: ThemeMode
  public let isDark: Bool
  public let backgroundTop: Color
  public let backgroundBottom: Color
  public let textPrimary: Color
  public let textSecondary: Color

  public init(palette: SkyPalette, mode: ThemeMode, systemColorScheme: ColorScheme) {
    self.palette = palette
    self.mode = mode

    let resolvedDark: Bool
    switch mode {
    case .system: resolvedDark = systemColorScheme == .dark
    case .dark:   resolvedDark = true
    case .light:  resolvedDark = false
    }
    self.isDark = resolvedDark

    let colors = Self.resolve(palette: palette, isDark: resolvedDark)
    self.backgroundTop = colors.top
    self.backgroundBottom = colors.bottom
    self.textPrimary = resolvedDark ? .white : .black
    self.textSecondary = resolvedDark ? Color.white.opacity(0.6) : Color.black.opacity(0.55)
  }

  /// Default theme used when env not provided (e.g. previews / snapshots).
  public static let `default` = SkyTheme(
    palette: .nightSky, mode: .dark, systemColorScheme: .dark)

  private static func resolve(palette: SkyPalette, isDark: Bool) -> (top: Color, bottom: Color) {
    switch (palette, isDark) {
    case (.nightSky, true):    return (Color(red: 0.06, green: 0.05, blue: 0.18), Color(red: 0.10, green: 0.10, blue: 0.30))
    case (.nightSky, false):   return (Color(red: 0.78, green: 0.74, blue: 0.92), Color(red: 0.92, green: 0.90, blue: 0.98))
    case (.mist, true):        return (Color(red: 0.05, green: 0.10, blue: 0.18), Color(red: 0.08, green: 0.16, blue: 0.26))
    case (.mist, false):       return (Color(red: 0.78, green: 0.84, blue: 0.92), Color(red: 0.90, green: 0.94, blue: 0.98))
    case (.dusk, true):        return (Color(red: 0.18, green: 0.06, blue: 0.06), Color(red: 0.30, green: 0.10, blue: 0.10))
    case (.dusk, false):       return (Color(red: 1.00, green: 0.78, blue: 0.74), Color(red: 1.00, green: 0.88, blue: 0.82))
    case (.komorebi, true):    return (Color(red: 0.05, green: 0.18, blue: 0.06), Color(red: 0.08, green: 0.26, blue: 0.10))
    case (.komorebi, false):   return (Color(red: 0.78, green: 0.92, blue: 0.74), Color(red: 0.90, green: 0.98, blue: 0.84))
    case (.akatsuki, true):    return (Color(red: 0.18, green: 0.05, blue: 0.18), Color(red: 0.30, green: 0.08, blue: 0.30))
    case (.akatsuki, false):   return (Color(red: 1.00, green: 0.84, blue: 0.92), Color(red: 1.00, green: 0.92, blue: 0.96))
    case (.silverFog, true):   return (Color(red: 0.10, green: 0.10, blue: 0.18), Color(red: 0.14, green: 0.14, blue: 0.22))
    case (.silverFog, false):  return (Color(red: 0.85, green: 0.85, blue: 0.88), Color(red: 0.94, green: 0.94, blue: 0.96))
    }
  }
}

private struct SkyThemeKey: EnvironmentKey {
  static let defaultValue: SkyTheme = .default
}

extension EnvironmentValues {
  public var skyTheme: SkyTheme {
    get { self[SkyThemeKey.self] }
    set { self[SkyThemeKey.self] = newValue }
  }
}

extension View {
  public func skyTheme(_ theme: SkyTheme) -> some View {
    self.environment(\.skyTheme, theme)
  }
}
```

- [ ] **Step 2: コンパイル確認**

```bash
swift build --package-path packages/AwaIroPresentation
```

Expected: `Build complete!`（`AwaIroDomain` 依存はすでに `Package.swift` に入っている）。

- [ ] **Step 3: コミット**

```bash
git add packages/AwaIroPresentation/Sources/AwaIroPresentation/Theme/SkyTheme.swift
git commit -m "feat(presentation): add SkyTheme value type + EnvironmentKey for palette propagation"
```

---

### Task 13: ThemeStore @Observable

**Files:**
- Create: `packages/AwaIroPresentation/Sources/AwaIroPresentation/Theme/ThemeStore.swift`
- Create: `packages/AwaIroPresentation/Tests/AwaIroPresentationTests/ThemeStoreTests.swift`

- [ ] **Step 1: テストを書く**

`packages/AwaIroPresentation/Tests/AwaIroPresentationTests/ThemeStoreTests.swift`:

```swift
import AwaIroDomain
import Foundation
import Testing

@testable import AwaIroPresentation

@Suite("ThemeStore @Observable")
@MainActor
struct ThemeStoreTests {

  @Test("starts with default values before load()")
  func initialDefaults() {
    let repo = FakeThemeRepo()
    let store = ThemeStore(repository: repo)
    #expect(store.palette == .nightSky)
    #expect(store.mode == .system)
  }

  @Test("load() reflects repository state")
  func loadFromRepo() async {
    let repo = FakeThemeRepo(palette: .dusk, mode: .dark)
    let store = ThemeStore(repository: repo)
    await store.load()
    #expect(store.palette == .dusk)
    #expect(store.mode == .dark)
  }

  @Test("setPalette writes to repository and updates state")
  func setPaletteWrites() async {
    let repo = FakeThemeRepo()
    let store = ThemeStore(repository: repo)
    await store.setPalette(.komorebi)
    #expect(store.palette == .komorebi)
    #expect(await repo.getPalette() == .komorebi)
  }

  @Test("setMode writes to repository and updates state")
  func setModeWrites() async {
    let repo = FakeThemeRepo()
    let store = ThemeStore(repository: repo)
    await store.setMode(.light)
    #expect(store.mode == .light)
    #expect(await repo.getMode() == .light)
  }
}

private final class FakeThemeRepo: ThemeRepository, @unchecked Sendable {
  private var palette: SkyPalette
  private var mode: ThemeMode
  init(palette: SkyPalette = .nightSky, mode: ThemeMode = .system) {
    self.palette = palette
    self.mode = mode
  }
  func getPalette() async -> SkyPalette { palette }
  func setPalette(_ p: SkyPalette) async { palette = p }
  func getMode() async -> ThemeMode { mode }
  func setMode(_ m: ThemeMode) async { mode = m }
}
```

- [ ] **Step 2: テストが fail することを確認**

```bash
swift test --package-path packages/AwaIroPresentation --filter ThemeStoreTests
```

Expected: コンパイルエラー。

- [ ] **Step 3: ThemeStore を実装**

`packages/AwaIroPresentation/Sources/AwaIroPresentation/Theme/ThemeStore.swift`:

```swift
import AwaIroDomain
import Foundation

@Observable
@MainActor
public final class ThemeStore {
  public private(set) var palette: SkyPalette = .nightSky
  public private(set) var mode: ThemeMode = .system

  private let repository: any ThemeRepository

  public init(repository: any ThemeRepository) {
    self.repository = repository
  }

  public func load() async {
    palette = await repository.getPalette()
    mode = await repository.getMode()
  }

  public func setPalette(_ p: SkyPalette) async {
    palette = p
    await repository.setPalette(p)
  }

  public func setMode(_ m: ThemeMode) async {
    mode = m
    await repository.setMode(m)
  }
}
```

- [ ] **Step 4: テスト緑を確認**

```bash
swift test --package-path packages/AwaIroPresentation --filter ThemeStoreTests
```

Expected: `4 tests passed`

- [ ] **Step 5: コミット**

```bash
git add packages/AwaIroPresentation/Sources/AwaIroPresentation/Theme/ThemeStore.swift \
        packages/AwaIroPresentation/Tests/AwaIroPresentationTests/ThemeStoreTests.swift
git commit -m "feat(presentation): add ThemeStore @Observable for palette/mode state"
```

---

## Presentation Layer — Components

### Task 14: AppRoute extension — .gallery / .photoDetail

**Files:**
- Modify: `packages/AwaIroPresentation/Sources/AwaIroPresentation/Navigation/AppRoute.swift`

- [ ] **Step 1: AppRoute に新ケースを追加**

`packages/AwaIroPresentation/Sources/AwaIroPresentation/Navigation/AppRoute.swift`:

```swift
import Foundation

public enum AppRoute: Hashable, Sendable {
  /// Captured photo, awaiting memo input and save.
  case memo(fileURL: URL, takenAt: Date)
  /// Bubble gallery — vertical scroll of bubbles.
  case gallery
  /// Photo detail screen — fullscreen photo + memo, swipeable.
  case photoDetail(photoId: UUID)
}
```

- [ ] **Step 2: コンパイル確認**

```bash
swift build --package-path packages/AwaIroPresentation
```

- [ ] **Step 3: コミット**

```bash
git add packages/AwaIroPresentation/Sources/AwaIroPresentation/Navigation/AppRoute.swift
git commit -m "feat(presentation): extend AppRoute with .gallery and .photoDetail"
```

---

### Task 15: BubbleGalleryItem component

**Files:**
- Create: `packages/AwaIroPresentation/Sources/AwaIroPresentation/Gallery/BubbleGalleryItem.swift`

- [ ] **Step 1: BubbleGalleryItem を実装**

`packages/AwaIroPresentation/Sources/AwaIroPresentation/Gallery/BubbleGalleryItem.swift`:

```swift
import AwaIroDomain
import SwiftUI

/// A single bubble in the gallery. Renders developed (with photo) or
/// undeveloped (translucent + remaining-time copy) variant.
public struct BubbleGalleryItem: View {
  public let photo: Photo
  public let now: Date
  public let size: CGFloat

  public init(photo: Photo, now: Date, size: CGFloat = 145) {
    self.photo = photo
    self.now = now
    self.size = size
  }

  @Environment(\.skyTheme) private var theme

  public var body: some View {
    ZStack {
      // Bubble shell — translucent gradient
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
        .overlay(
          Circle().stroke(Color.white.opacity(0.35), lineWidth: 1)
        )

      if photo.isDeveloped(now: now) {
        // Photo inside the bubble
        AsyncImage(url: photo.fileURL) { image in
          image.resizable().scaledToFill()
        } placeholder: {
          Color.white.opacity(0.05)
        }
        .frame(width: size * 0.78, height: size * 0.78)
        .clipShape(Circle())
        .accessibilityLabel("撮影した写真")
      } else {
        // Undeveloped — show remaining time
        Text(remainingCopy)
          .font(.caption)
          .foregroundStyle(theme.textSecondary)
          .accessibilityLabel("現像までの残り時間")
      }
    }
    .frame(width: size, height: size)
  }

  private var remainingCopy: String {
    let secs = max(0, photo.remainingUntilDeveloped(now: now))
    let hours = Int(secs / 3600)
    if hours <= 0 {
      return "もうすぐ"
    } else {
      return "あと\(hours)時間"
    }
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
```

- [ ] **Step 2: コンパイル確認**

```bash
swift build --package-path packages/AwaIroPresentation
```

- [ ] **Step 3: コミット**

```bash
git add packages/AwaIroPresentation/Sources/AwaIroPresentation/Gallery/BubbleGalleryItem.swift
git commit -m "feat(presentation): add BubbleGalleryItem component (developed/undeveloped variants)"
```

---

### Task 16: GalleryViewModel

**Files:**
- Create: `packages/AwaIroPresentation/Sources/AwaIroPresentation/Gallery/GalleryViewModel.swift`
- Create: `packages/AwaIroPresentation/Tests/AwaIroPresentationTests/GalleryViewModelTests.swift`

- [ ] **Step 1: テストを書く**

`packages/AwaIroPresentation/Tests/AwaIroPresentationTests/GalleryViewModelTests.swift`:

```swift
import AwaIroDomain
import Foundation
import Testing

@testable import AwaIroPresentation

@Suite("GalleryViewModel")
@MainActor
struct GalleryViewModelTests {

  private func makePhoto(taken: Date, id: UUID = UUID()) -> Photo {
    Photo(
      id: id, takenAt: taken, developedAt: taken.addingTimeInterval(86400),
      fileURL: URL(fileURLWithPath: "/tmp/\(id).jpg"), memo: nil)
  }

  @Test("starts in loading state")
  func initialLoading() {
    let usecase = DevelopPhotoUseCase(repository: FakeRepo(seed: []))
    let vm = GalleryViewModel(usecase: usecase)
    if case .loading = vm.state {} else {
      Issue.record("expected loading, got \(vm.state)")
    }
  }

  @Test("load with no photos transitions to empty")
  func loadEmpty() async {
    let usecase = DevelopPhotoUseCase(repository: FakeRepo(seed: []))
    let vm = GalleryViewModel(usecase: usecase)
    await vm.load(now: Date())
    if case .empty = vm.state {} else {
      Issue.record("expected empty, got \(vm.state)")
    }
  }

  @Test("load with photos transitions to loaded with current `now`")
  func loadWithPhotos() async {
    let now = Date(timeIntervalSince1970: 1_730_000_000)
    let p1 = makePhoto(taken: now.addingTimeInterval(-12 * 3600))  // 12h ago
    let p2 = makePhoto(taken: now.addingTimeInterval(-30 * 3600))  // 30h ago

    let usecase = DevelopPhotoUseCase(repository: FakeRepo(seed: [p2, p1]))
    let vm = GalleryViewModel(usecase: usecase)
    await vm.load(now: now)

    guard case .loaded(let photos, let asOf) = vm.state else {
      Issue.record("expected loaded, got \(vm.state)")
      return
    }
    #expect(photos.count == 2)
    #expect(photos[0].takenAt > photos[1].takenAt)  // newest first
    #expect(asOf == now)
  }

  @Test("tickNow updates 'asOf' so isDeveloped flips")
  func tickUpdatesNow() async {
    let now = Date(timeIntervalSince1970: 1_730_000_000)
    let p = makePhoto(taken: now.addingTimeInterval(-23 * 3600 - 50 * 60))  // 23h50m ago
    let usecase = DevelopPhotoUseCase(repository: FakeRepo(seed: [p]))
    let vm = GalleryViewModel(usecase: usecase)
    await vm.load(now: now)

    if case .loaded(let photos, _) = vm.state {
      #expect(!photos[0].isDeveloped(now: now))
    }

    let later = now.addingTimeInterval(20 * 60)  // +20min → 24h10m total
    vm.tickNow(later)

    if case .loaded(let photos, let asOf) = vm.state {
      #expect(asOf == later)
      #expect(photos[0].isDeveloped(now: asOf))
    } else {
      Issue.record("expected loaded after tick")
    }
  }

  @Test("repository failure transitions to failed")
  func loadFailed() async {
    struct Boom: Error {}
    let usecase = DevelopPhotoUseCase(repository: FailingRepo(error: Boom()))
    let vm = GalleryViewModel(usecase: usecase)
    await vm.load(now: Date())
    if case .failed = vm.state {} else {
      Issue.record("expected failed, got \(vm.state)")
    }
  }
}

private final class FakeRepo: PhotoRepository, @unchecked Sendable {
  private var photos: [Photo]
  init(seed: [Photo]) { self.photos = seed }
  func todayPhoto(now: Date) async throws -> Photo? { nil }
  func insert(_ photo: Photo) async throws { photos.append(photo) }
  func findAllOrderByTakenAtDesc() async throws -> [Photo] {
    photos.sorted { $0.takenAt > $1.takenAt }
  }
  func findById(_ id: UUID) async throws -> Photo? { photos.first { $0.id == id } }
  func updateMemo(id: UUID, memo: String?) async throws {}
}

private final class FailingRepo: PhotoRepository, @unchecked Sendable {
  private let error: any Error
  init(error: any Error) { self.error = error }
  func todayPhoto(now: Date) async throws -> Photo? { throw error }
  func insert(_ photo: Photo) async throws { throw error }
  func findAllOrderByTakenAtDesc() async throws -> [Photo] { throw error }
  func findById(_ id: UUID) async throws -> Photo? { throw error }
  func updateMemo(id: UUID, memo: String?) async throws { throw error }
}
```

- [ ] **Step 2: テストが fail することを確認**

```bash
swift test --package-path packages/AwaIroPresentation --filter GalleryViewModelTests
```

Expected: コンパイルエラー。

- [ ] **Step 3: GalleryViewModel を実装**

`packages/AwaIroPresentation/Sources/AwaIroPresentation/Gallery/GalleryViewModel.swift`:

```swift
import AwaIroDomain
import Foundation

public enum GalleryState: Equatable, Sendable {
  case loading
  case empty
  case loaded(photos: [Photo], asOf: Date)
  case failed(message: String)
}

@Observable
@MainActor
public final class GalleryViewModel {
  public private(set) var state: GalleryState = .loading
  private let usecase: DevelopPhotoUseCase

  public init(usecase: DevelopPhotoUseCase) {
    self.usecase = usecase
  }

  public func load(now: Date) async {
    state = .loading
    do {
      let photos = try await usecase.execute()
      if photos.isEmpty {
        state = .empty
      } else {
        state = .loaded(photos: photos, asOf: now)
      }
    } catch {
      state = .failed(message: String(describing: error))
    }
  }

  /// Updates the `asOf` reference time so `isDeveloped` re-evaluates without re-fetching.
  /// Called by a periodic tick (e.g. every 60s) while the gallery is visible.
  public func tickNow(_ newNow: Date) {
    if case .loaded(let photos, _) = state {
      state = .loaded(photos: photos, asOf: newNow)
    }
  }
}
```

- [ ] **Step 4: テスト緑を確認**

```bash
swift test --package-path packages/AwaIroPresentation --filter GalleryViewModelTests
```

Expected: `5 tests passed`

- [ ] **Step 5: コミット**

```bash
git add packages/AwaIroPresentation/Sources/AwaIroPresentation/Gallery/GalleryViewModel.swift \
        packages/AwaIroPresentation/Tests/AwaIroPresentationTests/GalleryViewModelTests.swift
git commit -m "feat(presentation): add GalleryViewModel with state machine + tickNow"
```

---

### Task 17: GalleryContentView + GalleryScreen + Snapshot tests

**Files:**
- Create: `packages/AwaIroPresentation/Sources/AwaIroPresentation/Gallery/GalleryScreen.swift`
- Create: `packages/AwaIroPresentation/Tests/AwaIroPresentationTests/GalleryScreenSnapshotTests.swift`

- [ ] **Step 1: GalleryContentView + GalleryScreen を実装**

`packages/AwaIroPresentation/Sources/AwaIroPresentation/Gallery/GalleryScreen.swift`:

```swift
import AwaIroDomain
import SwiftUI

/// State-driven content view for snapshot testing.
public struct GalleryContentView: View {
  public let state: GalleryState
  public let onTapPhoto: (UUID) -> Void
  public let onTapBack: () -> Void
  public let onTapMenu: () -> Void

  @Environment(\.skyTheme) private var theme

  public init(
    state: GalleryState,
    onTapPhoto: @escaping (UUID) -> Void = { _ in },
    onTapBack: @escaping () -> Void = {},
    onTapMenu: @escaping () -> Void = {}
  ) {
    self.state = state
    self.onTapPhoto = onTapPhoto
    self.onTapBack = onTapBack
    self.onTapMenu = onTapMenu
  }

  public var body: some View {
    ZStack {
      LinearGradient(
        colors: [theme.backgroundTop, theme.backgroundBottom],
        startPoint: .top, endPoint: .bottom
      )
      .ignoresSafeArea()

      content
    }
  }

  @ViewBuilder
  private var content: some View {
    switch state {
    case .loading:
      ProgressView().tint(theme.textPrimary)
        .accessibilityLabel("読み込み中")

    case .empty:
      VStack(spacing: 12) {
        Text("まだ泡がありません")
          .foregroundStyle(theme.textPrimary)
        Text("撮影すると、ここに泡が浮かびます")
          .font(.caption)
          .foregroundStyle(theme.textSecondary)
      }

    case .loaded(let photos, let asOf):
      ScrollView {
        LazyVStack(spacing: 32) {
          ForEach(photos, id: \.id) { photo in
            BubbleGalleryItem(photo: photo, now: asOf, size: 160)
              .onTapGesture {
                if photo.isDeveloped(now: asOf) {
                  onTapPhoto(photo.id)
                }
              }
              .accessibilityAddTraits(.isButton)
          }
        }
        .padding(.vertical, 40)
      }

    case .failed(let message):
      VStack(spacing: 12) {
        Text("読み込みに失敗しました")
          .foregroundStyle(theme.textPrimary)
        Text(message)
          .font(.caption)
          .foregroundStyle(theme.textSecondary)
      }
    }
  }
}

#if canImport(UIKit)
  /// Production GalleryScreen — composes GalleryContentView with VM lifecycle + tick timer.
  public struct GalleryScreen: View {
    @State private var viewModel: GalleryViewModel
    private let onTapPhoto: (UUID) -> Void
    private let onTapBack: () -> Void
    private let onTapMenu: () -> Void

    public init(
      viewModel: GalleryViewModel,
      onTapPhoto: @escaping (UUID) -> Void,
      onTapBack: @escaping () -> Void,
      onTapMenu: @escaping () -> Void
    ) {
      _viewModel = State(initialValue: viewModel)
      self.onTapPhoto = onTapPhoto
      self.onTapBack = onTapBack
      self.onTapMenu = onTapMenu
    }

    public var body: some View {
      GalleryContentView(
        state: viewModel.state,
        onTapPhoto: onTapPhoto,
        onTapBack: onTapBack,
        onTapMenu: onTapMenu
      )
      .task {
        await viewModel.load(now: Date())
        // Tick every 60s to flip undeveloped → developed without re-querying DB.
        while !Task.isCancelled {
          try? await Task.sleep(for: .seconds(60))
          viewModel.tickNow(Date())
        }
      }
    }
  }
#endif

#if DEBUG
  #Preview("loaded — mixed") {
    let now = Date(timeIntervalSince1970: 1_730_000_000)
    GalleryContentView(
      state: .loaded(
        photos: [
          Photo(id: UUID(), takenAt: now.addingTimeInterval(-12 * 3600),
                developedAt: now.addingTimeInterval(12 * 3600),
                fileURL: URL(fileURLWithPath: "/tmp/a.jpg"), memo: nil),
          Photo(id: UUID(), takenAt: now.addingTimeInterval(-30 * 3600),
                developedAt: now.addingTimeInterval(-6 * 3600),
                fileURL: URL(fileURLWithPath: "/tmp/b.jpg"), memo: nil),
        ],
        asOf: now
      )
    )
  }

  #Preview("empty") {
    GalleryContentView(state: .empty)
  }
#endif
```

- [ ] **Step 2: Snapshot テストを書く**

`packages/AwaIroPresentation/Tests/AwaIroPresentationTests/GalleryScreenSnapshotTests.swift`:

```swift
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
```

- [ ] **Step 3: テスト実行（最初は record モードで snapshot を保存）**

```bash
SNAPSHOTS_RECORDING=true swift test --package-path packages/AwaIroPresentation --filter GalleryScreenSnapshotTests
```

Expected: テストが「snapshot recorded」で fail（ADR 0006 仕様 — 初回は record して visual diff を確認）。`__Snapshots__/GalleryScreenSnapshotTests/` に新規 PNG が生成される。

- [ ] **Step 4: Visual diff を確認 → 通常モードで再実行**

```bash
swift test --package-path packages/AwaIroPresentation --filter GalleryScreenSnapshotTests
```

Expected: `3 tests passed`

- [ ] **Step 5: コミット（snapshot PNG も含む）**

```bash
git add packages/AwaIroPresentation/Sources/AwaIroPresentation/Gallery/GalleryScreen.swift \
        packages/AwaIroPresentation/Tests/AwaIroPresentationTests/GalleryScreenSnapshotTests.swift \
        packages/AwaIroPresentation/Tests/AwaIroPresentationTests/__Snapshots__/GalleryScreenSnapshotTests
git commit -m "feat(presentation): GalleryContentView + GalleryScreen with G3 guardrail snapshot"
```

---

### Task 18: PhotoDetailViewModel

**Files:**
- Create: `packages/AwaIroPresentation/Sources/AwaIroPresentation/PhotoDetail/PhotoDetailViewModel.swift`
- Create: `packages/AwaIroPresentation/Tests/AwaIroPresentationTests/PhotoDetailViewModelTests.swift`

- [ ] **Step 1: テストを書く**

`packages/AwaIroPresentation/Tests/AwaIroPresentationTests/PhotoDetailViewModelTests.swift`:

```swift
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
      id: id, takenAt: now, developedAt: now.addingTimeInterval(-3600),  // already developed
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
```

- [ ] **Step 2: テストが fail することを確認**

```bash
swift test --package-path packages/AwaIroPresentation --filter PhotoDetailViewModelTests
```

Expected: コンパイルエラー。

- [ ] **Step 3: PhotoDetailViewModel を実装**

`packages/AwaIroPresentation/Sources/AwaIroPresentation/PhotoDetail/PhotoDetailViewModel.swift`:

```swift
import AwaIroDomain
import Foundation

public enum PhotoDetailState: Equatable, Sendable {
  case viewing(Photo)
  case editing(Photo, draft: String)
  case saving(Photo)
  case failed(Photo, message: String)
}

@Observable
@MainActor
public final class PhotoDetailViewModel {
  public private(set) var state: PhotoDetailState
  private let updateMemo: UpdateMemoUseCase

  public init(photo: Photo, updateMemo: UpdateMemoUseCase) {
    self.state = .viewing(photo)
    self.updateMemo = updateMemo
  }

  public func startEditing() {
    if case .viewing(let p) = state {
      state = .editing(p, draft: p.memo ?? "")
    }
  }

  public func setDraft(_ s: String) {
    if case .editing(let p, _) = state {
      state = .editing(p, draft: s)
    }
  }

  public func cancelEditing() {
    if case .editing(let p, _) = state {
      state = .viewing(p)
    }
  }

  public func save() async {
    guard case .editing(let p, let draft) = state else { return }
    let memoOrNil: String? = draft.isEmpty ? nil : draft
    state = .saving(p)
    do {
      try await updateMemo.execute(id: p.id, memo: memoOrNil)
      let updated = Photo(
        id: p.id, takenAt: p.takenAt, developedAt: p.developedAt,
        fileURL: p.fileURL, memo: memoOrNil)
      state = .viewing(updated)
    } catch {
      state = .failed(p, message: String(describing: error))
    }
  }
}
```

- [ ] **Step 4: テスト緑を確認**

```bash
swift test --package-path packages/AwaIroPresentation --filter PhotoDetailViewModelTests
```

Expected: `6 tests passed`

- [ ] **Step 5: コミット**

```bash
git add packages/AwaIroPresentation/Sources/AwaIroPresentation/PhotoDetail/PhotoDetailViewModel.swift \
        packages/AwaIroPresentation/Tests/AwaIroPresentationTests/PhotoDetailViewModelTests.swift
git commit -m "feat(presentation): add PhotoDetailViewModel with viewing/editing/saving states"
```

---

### Task 19: PhotoDetailContentView + PhotoDetailScreen + Snapshot tests

**Files:**
- Create: `packages/AwaIroPresentation/Sources/AwaIroPresentation/PhotoDetail/PhotoDetailScreen.swift`
- Create: `packages/AwaIroPresentation/Tests/AwaIroPresentationTests/PhotoDetailScreenSnapshotTests.swift`

- [ ] **Step 1: PhotoDetailContentView + PhotoDetailScreen を実装**

`packages/AwaIroPresentation/Sources/AwaIroPresentation/PhotoDetail/PhotoDetailScreen.swift`:

```swift
import AwaIroDomain
import SwiftUI

public struct PhotoDetailContentView: View {
  public let state: PhotoDetailState
  public let onStartEdit: () -> Void
  public let onCancelEdit: () -> Void
  public let onSetDraft: (String) -> Void
  public let onSave: () -> Void
  public let onTapShare: () -> Void

  @Environment(\.skyTheme) private var theme

  public init(
    state: PhotoDetailState,
    onStartEdit: @escaping () -> Void = {},
    onCancelEdit: @escaping () -> Void = {},
    onSetDraft: @escaping (String) -> Void = { _ in },
    onSave: @escaping () -> Void = {},
    onTapShare: @escaping () -> Void = {}
  ) {
    self.state = state
    self.onStartEdit = onStartEdit
    self.onCancelEdit = onCancelEdit
    self.onSetDraft = onSetDraft
    self.onSave = onSave
    self.onTapShare = onTapShare
  }

  public var body: some View {
    ZStack {
      LinearGradient(
        colors: [theme.backgroundTop, theme.backgroundBottom],
        startPoint: .top, endPoint: .bottom
      )
      .ignoresSafeArea()
      content
    }
  }

  private var photo: Photo {
    switch state {
    case .viewing(let p), .editing(let p, _), .saving(let p), .failed(let p, _): return p
    }
  }

  @ViewBuilder
  private var content: some View {
    VStack(spacing: 24) {
      AsyncImage(url: photo.fileURL) { image in
        image
          .resizable()
          .scaledToFit()
          .clipShape(RoundedRectangle(cornerRadius: 16))
      } placeholder: {
        RoundedRectangle(cornerRadius: 16)
          .fill(.white.opacity(0.08))
          .overlay(ProgressView().tint(theme.textPrimary))
      }
      .frame(maxHeight: .infinity)
      .padding(.horizontal)

      memoSection

      // Share placeholder (Sprint 3 implements actual share)
      Button(action: onTapShare) {
        Label("シェア", systemImage: "square.and.arrow.up")
          .foregroundStyle(theme.textPrimary)
      }
      .buttonStyle(.bordered)
      .tint(theme.textPrimary)
      .accessibilityHint("Sprint 3 で実装予定")
      .padding(.bottom)
    }
  }

  @ViewBuilder
  private var memoSection: some View {
    switch state {
    case .viewing(let p):
      HStack(alignment: .top) {
        Text(p.memo ?? "メモなし")
          .foregroundStyle(p.memo == nil ? theme.textSecondary : theme.textPrimary)
          .frame(maxWidth: .infinity, alignment: .leading)
        Button(action: onStartEdit) {
          Image(systemName: "pencil")
        }
        .foregroundStyle(theme.textPrimary)
        .accessibilityLabel("メモを編集")
      }
      .padding(.horizontal)

    case .editing(_, let draft):
      VStack(spacing: 8) {
        TextField(
          "一言（任意）",
          text: Binding(get: { draft }, set: { onSetDraft($0) })
        )
        .textFieldStyle(.roundedBorder)
        .accessibilityLabel("メモ入力")

        HStack(spacing: 16) {
          Button("やめる", action: onCancelEdit)
            .buttonStyle(.bordered)
          Button("保存", action: onSave)
            .buttonStyle(.borderedProminent)
        }
      }
      .padding(.horizontal)

    case .saving:
      ProgressView()
        .tint(theme.textPrimary)
        .padding()

    case .failed(_, let message):
      VStack(spacing: 8) {
        Text(message)
          .font(.caption)
          .foregroundStyle(.red)
          .multilineTextAlignment(.center)
        Button("やめる", action: onCancelEdit)
          .buttonStyle(.bordered)
      }
      .padding(.horizontal)
    }
  }
}

#if canImport(UIKit)
  /// PhotoDetailScreen — fullscreen viewer with TabView pager (left/right swipe).
  public struct PhotoDetailScreen: View {
    @State private var viewModels: [UUID: PhotoDetailViewModel]
    private let photos: [Photo]
    @State private var selectedId: UUID
    private let updateMemoFactory: (Photo) -> PhotoDetailViewModel

    public init(
      photos: [Photo],
      initialPhotoId: UUID,
      updateMemoFactory: @escaping (Photo) -> PhotoDetailViewModel
    ) {
      self.photos = photos
      self._selectedId = State(initialValue: initialPhotoId)
      self.updateMemoFactory = updateMemoFactory
      var initial: [UUID: PhotoDetailViewModel] = [:]
      for p in photos { initial[p.id] = updateMemoFactory(p) }
      self._viewModels = State(initialValue: initial)
    }

    public var body: some View {
      TabView(selection: $selectedId) {
        ForEach(photos, id: \.id) { photo in
          PhotoDetailContentView(
            state: viewModels[photo.id]?.state ?? .viewing(photo),
            onStartEdit: { viewModels[photo.id]?.startEditing() },
            onCancelEdit: { viewModels[photo.id]?.cancelEditing() },
            onSetDraft: { viewModels[photo.id]?.setDraft($0) },
            onSave: { Task { await viewModels[photo.id]?.save() } },
            onTapShare: {}
          )
          .tag(photo.id)
        }
      }
      .tabViewStyle(.page(indexDisplayMode: .never))
    }
  }
#endif

#if DEBUG
  #Preview("viewing — with memo") {
    let now = Date(timeIntervalSince1970: 1_730_000_000)
    PhotoDetailContentView(
      state: .viewing(Photo(
        id: UUID(), takenAt: now,
        developedAt: now.addingTimeInterval(-3600),
        fileURL: URL(fileURLWithPath: "/tmp/x.jpg"), memo: "朝の散歩"
      ))
    )
  }

  #Preview("viewing — empty memo") {
    let now = Date(timeIntervalSince1970: 1_730_000_000)
    PhotoDetailContentView(
      state: .viewing(Photo(
        id: UUID(), takenAt: now,
        developedAt: now.addingTimeInterval(-3600),
        fileURL: URL(fileURLWithPath: "/tmp/x.jpg"), memo: nil
      ))
    )
  }

  #Preview("editing") {
    let now = Date(timeIntervalSince1970: 1_730_000_000)
    PhotoDetailContentView(
      state: .editing(
        Photo(
          id: UUID(), takenAt: now,
          developedAt: now.addingTimeInterval(-3600),
          fileURL: URL(fileURLWithPath: "/tmp/x.jpg"), memo: "前のメモ"),
        draft: "編集中のメモ"
      )
    )
  }
#endif
```

- [ ] **Step 2: Snapshot テストを書く**

`packages/AwaIroPresentation/Tests/AwaIroPresentationTests/PhotoDetailScreenSnapshotTests.swift`:

```swift
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
```

- [ ] **Step 3: Snapshot を record（初回）**

```bash
SNAPSHOTS_RECORDING=true swift test --package-path packages/AwaIroPresentation --filter PhotoDetailScreenSnapshotTests
```

- [ ] **Step 4: 通常実行で緑を確認**

```bash
swift test --package-path packages/AwaIroPresentation --filter PhotoDetailScreenSnapshotTests
```

Expected: `4 tests passed`

- [ ] **Step 5: コミット**

```bash
git add packages/AwaIroPresentation/Sources/AwaIroPresentation/PhotoDetail/PhotoDetailScreen.swift \
        packages/AwaIroPresentation/Tests/AwaIroPresentationTests/PhotoDetailScreenSnapshotTests.swift \
        packages/AwaIroPresentation/Tests/AwaIroPresentationTests/__Snapshots__/PhotoDetailScreenSnapshotTests
git commit -m "feat(presentation): PhotoDetailContentView + PhotoDetailScreen with TabView pager"
```

---

### Task 20: BottomActionBar component

**Files:**
- Create: `packages/AwaIroPresentation/Sources/AwaIroPresentation/Components/BottomActionBar.swift`

- [ ] **Step 1: BottomActionBar を実装**

`packages/AwaIroPresentation/Sources/AwaIroPresentation/Components/BottomActionBar.swift`:

```swift
import SwiftUI

/// Reusable bottom bar with leading + trailing icon buttons.
/// Used by HomeScreen (gallery + menu) and GalleryScreen (home + menu).
public struct BottomActionBar: View {
  public let leadingSystemName: String
  public let leadingLabel: String
  public let trailingSystemName: String
  public let trailingLabel: String
  public let onTapLeading: () -> Void
  public let onTapTrailing: () -> Void

  @Environment(\.skyTheme) private var theme

  public init(
    leadingSystemName: String,
    leadingLabel: String,
    trailingSystemName: String,
    trailingLabel: String,
    onTapLeading: @escaping () -> Void,
    onTapTrailing: @escaping () -> Void
  ) {
    self.leadingSystemName = leadingSystemName
    self.leadingLabel = leadingLabel
    self.trailingSystemName = trailingSystemName
    self.trailingLabel = trailingLabel
    self.onTapLeading = onTapLeading
    self.onTapTrailing = onTapTrailing
  }

  public var body: some View {
    HStack {
      Button(action: onTapLeading) {
        Image(systemName: leadingSystemName)
          .font(.title2)
      }
      .accessibilityLabel(leadingLabel)
      Spacer()
      Button(action: onTapTrailing) {
        Image(systemName: trailingSystemName)
          .font(.title2)
      }
      .accessibilityLabel(trailingLabel)
    }
    .foregroundStyle(theme.textPrimary)
    .padding(.horizontal, 24)
    .padding(.bottom, 16)
  }
}
```

- [ ] **Step 2: コンパイル確認 + コミット**

```bash
swift build --package-path packages/AwaIroPresentation
git add packages/AwaIroPresentation/Sources/AwaIroPresentation/Components/BottomActionBar.swift
git commit -m "feat(presentation): add BottomActionBar component for Home + Gallery"
```

---

### Task 21: PaletteSheet + Snapshot tests

**Files:**
- Create: `packages/AwaIroPresentation/Sources/AwaIroPresentation/Components/PaletteSheet.swift`
- Create: `packages/AwaIroPresentation/Tests/AwaIroPresentationTests/PaletteSheetSnapshotTests.swift`

- [ ] **Step 1: PaletteSheet を実装**

`packages/AwaIroPresentation/Sources/AwaIroPresentation/Components/PaletteSheet.swift`:

```swift
import AwaIroDomain
import SwiftUI

public struct PaletteSheet: View {
  public let selectedPalette: SkyPalette
  public let selectedMode: ThemeMode
  public let onPickPalette: (SkyPalette) -> Void
  public let onPickMode: (ThemeMode) -> Void

  @Environment(\.skyTheme) private var theme

  public init(
    selectedPalette: SkyPalette,
    selectedMode: ThemeMode,
    onPickPalette: @escaping (SkyPalette) -> Void,
    onPickMode: @escaping (ThemeMode) -> Void
  ) {
    self.selectedPalette = selectedPalette
    self.selectedMode = selectedMode
    self.onPickPalette = onPickPalette
    self.onPickMode = onPickMode
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: 24) {
      Text("空の色")
        .font(.headline)
        .foregroundStyle(theme.textPrimary)

      LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 3), spacing: 16) {
        ForEach(SkyPalette.allCases, id: \.self) { palette in
          paletteSwatch(palette)
        }
      }

      Divider().background(theme.textSecondary)

      Text("テーマ")
        .font(.headline)
        .foregroundStyle(theme.textPrimary)

      HStack(spacing: 12) {
        ForEach(ThemeMode.allCases, id: \.self) { mode in
          modeButton(mode)
        }
      }
    }
    .padding()
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(
      LinearGradient(
        colors: [theme.backgroundTop, theme.backgroundBottom],
        startPoint: .top, endPoint: .bottom
      )
    )
  }

  @ViewBuilder
  private func paletteSwatch(_ palette: SkyPalette) -> some View {
    Button {
      onPickPalette(palette)
    } label: {
      VStack(spacing: 4) {
        let preview = SkyTheme(palette: palette, mode: theme.mode, systemColorScheme: theme.isDark ? .dark : .light)
        Circle()
          .fill(
            LinearGradient(
              colors: [preview.backgroundTop, preview.backgroundBottom],
              startPoint: .top, endPoint: .bottom
            )
          )
          .frame(width: 56, height: 56)
          .overlay(
            Circle()
              .stroke(palette == selectedPalette ? theme.textPrimary : .clear, lineWidth: 2)
          )
        Text(palette.displayName)
          .font(.caption)
          .foregroundStyle(theme.textPrimary)
      }
    }
    .accessibilityLabel(palette.displayName)
    .accessibilityAddTraits(palette == selectedPalette ? [.isSelected, .isButton] : .isButton)
  }

  @ViewBuilder
  private func modeButton(_ mode: ThemeMode) -> some View {
    let label: String = {
      switch mode {
      case .system: "システム"
      case .dark: "暗い"
      case .light: "明るい"
      }
    }()
    Button(label) { onPickMode(mode) }
      .buttonStyle(.bordered)
      .tint(theme.textPrimary)
      .opacity(mode == selectedMode ? 1.0 : 0.5)
      .accessibilityAddTraits(mode == selectedMode ? .isSelected : [])
  }
}

#if DEBUG
  #Preview {
    PaletteSheet(
      selectedPalette: .nightSky, selectedMode: .system,
      onPickPalette: { _ in }, onPickMode: { _ in }
    )
  }
#endif
```

- [ ] **Step 2: Snapshot テスト**

`packages/AwaIroPresentation/Tests/AwaIroPresentationTests/PaletteSheetSnapshotTests.swift`:

```swift
#if canImport(UIKit)
  import AwaIroDomain
  import SnapshotTesting
  import SwiftUI
  import Testing
  import UIKit

  @testable import AwaIroPresentation

  @Suite("PaletteSheet snapshot")
  @MainActor
  struct PaletteSheetSnapshotTests {

    @Test("default selection snapshot is stable")
    func defaultSelectionSnapshot() {
      let view = PaletteSheet(
        selectedPalette: .nightSky, selectedMode: .system,
        onPickPalette: { _ in }, onPickMode: { _ in }
      ).skyTheme(.default)
      let host = UIHostingController(rootView: view)
      assertSnapshot(of: host, as: .image(on: .iPhoneX(.portrait)))
    }

    @Test("dusk + light selection snapshot is stable")
    func duskLightSelection() {
      let theme = SkyTheme(palette: .dusk, mode: .light, systemColorScheme: .light)
      let view = PaletteSheet(
        selectedPalette: .dusk, selectedMode: .light,
        onPickPalette: { _ in }, onPickMode: { _ in }
      ).skyTheme(theme)
      let host = UIHostingController(rootView: view)
      assertSnapshot(of: host, as: .image(on: .iPhoneX(.portrait)))
    }
  }
#endif
```

- [ ] **Step 3: Snapshot を record（初回） → 通常テストで緑**

```bash
SNAPSHOTS_RECORDING=true swift test --package-path packages/AwaIroPresentation --filter PaletteSheetSnapshotTests
swift test --package-path packages/AwaIroPresentation --filter PaletteSheetSnapshotTests
```

Expected: `2 tests passed`

- [ ] **Step 4: コミット**

```bash
git add packages/AwaIroPresentation/Sources/AwaIroPresentation/Components/PaletteSheet.swift \
        packages/AwaIroPresentation/Tests/AwaIroPresentationTests/PaletteSheetSnapshotTests.swift \
        packages/AwaIroPresentation/Tests/AwaIroPresentationTests/__Snapshots__/PaletteSheetSnapshotTests
git commit -m "feat(presentation): add PaletteSheet with palette + mode selection"
```

---

## App Integration

### Task 22: AppContainer に新ファクトリを追加

**Files:**
- Modify: `App/AwaIro/AppContainer.swift`

- [ ] **Step 1: AppContainer を更新**

`App/AwaIro/AppContainer.swift`:

```swift
import AVFoundation
import AwaIroData
import AwaIroDomain
import AwaIroPlatform
import AwaIroPresentation
import Foundation

@MainActor
final class AppContainer {
  let filePathProvider: FilePathProvider
  let photoRepository: any PhotoRepository
  let themeRepository: any ThemeRepository
  let getTodayPhotoUseCase: GetTodayPhotoUseCase
  let recordPhotoUseCase: RecordPhotoUseCase
  let developPhotoUseCase: DevelopPhotoUseCase
  let updateMemoUseCase: UpdateMemoUseCase
  let cameraPermission: any CameraPermission
  let camera: any CameraController
  let photoFileStore: PhotoFileStore
  let themeStore: ThemeStore

  init() throws {
    let provider = try FilePathProvider.defaultProduction()
    self.filePathProvider = provider

    let pool = try DatabaseFactory.makePool(at: provider.databaseURL)
    let repo = PhotoRepositoryImpl(writer: pool)
    self.photoRepository = repo

    let themeRepo = UserDefaultsThemeRepository()
    self.themeRepository = themeRepo

    self.getTodayPhotoUseCase = GetTodayPhotoUseCase(repository: repo)
    self.recordPhotoUseCase = RecordPhotoUseCase(repository: repo)
    self.developPhotoUseCase = DevelopPhotoUseCase(repository: repo)
    self.updateMemoUseCase = UpdateMemoUseCase(repository: repo)
    self.cameraPermission = AVFoundationCameraPermission()
    self.camera = AVFoundationCameraController()
    self.photoFileStore = PhotoFileStore(filePathProvider: provider)
    self.themeStore = ThemeStore(repository: themeRepo)
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

  func makeGalleryViewModel() -> GalleryViewModel {
    GalleryViewModel(usecase: developPhotoUseCase)
  }

  func makePhotoDetailViewModel(photo: Photo) -> PhotoDetailViewModel {
    PhotoDetailViewModel(photo: photo, updateMemo: updateMemoUseCase)
  }
}
```

- [ ] **Step 2: iOS Simulator ビルドが通ることを確認**

```bash
xcodebuild build -project App/AwaIro.xcodeproj -scheme AwaIro \
  -destination 'platform=iOS Simulator,name=iPhone 16 (AwaIro)'
```

Expected: `BUILD SUCCESSFUL`

- [ ] **Step 3: コミット**

```bash
git add App/AwaIro/AppContainer.swift
git commit -m "feat(app): extend AppContainer with ThemeStore + Develop/UpdateMemo factories"
```

---

### Task 23: RootContentView を Gallery / PhotoDetail / Theme 対応に更新

**Files:**
- Modify: `App/AwaIro/RootContentView.swift`
- Modify: `packages/AwaIroPresentation/Sources/AwaIroPresentation/Home/HomeScreen.swift`

- [ ] **Step 1: HomeScreen に BottomActionBar + onTapGallery / onTapMenu を追加**

`packages/AwaIroPresentation/Sources/AwaIroPresentation/Home/HomeScreen.swift` の `HomeScreen` を修正（既存 `body` の `HomeContentView` に overlay する形）:

```swift
public struct HomeScreen: View {
  @State private var viewModel: HomeViewModel
  private let camera: any CameraController
  private let onCaptured: @MainActor (URL, Date) -> Void
  private let onTapGallery: () -> Void
  private let onTapMenu: () -> Void

  public init(
    viewModel: HomeViewModel,
    camera: any CameraController,
    onCaptured: @escaping @MainActor (URL, Date) -> Void,
    onTapGallery: @escaping () -> Void,
    onTapMenu: @escaping () -> Void
  ) {
    _viewModel = State(initialValue: viewModel)
    self.camera = camera
    self.onCaptured = onCaptured
    self.onTapGallery = onTapGallery
    self.onTapMenu = onTapMenu
  }

  public var body: some View {
    HomeContentView(
      state: viewModel.state,
      permission: viewModel.permission,
      bubble: {
        BubbleCameraView(camera: camera) {
          let takenAt = Date()
          if let url = await viewModel.capturePhoto() {
            await onCaptured(url, takenAt)
          }
        }
      },
      onRequestPermission: {
        Task { await viewModel.requestCameraIfNeeded() }
      }
    )
    .overlay(alignment: .bottom) {
      BottomActionBar(
        leadingSystemName: "circle.grid.3x3.fill",
        leadingLabel: "泡たち",
        trailingSystemName: "paintpalette",
        trailingLabel: "メニュー",
        onTapLeading: onTapGallery,
        onTapTrailing: onTapMenu
      )
    }
    .task {
      await viewModel.load(now: Date())
    }
  }
}
```

> Snapshot tests `HomeScreenSnapshotTests` は `HomeContentView` を直接 driving しているので、HomeScreen の API 変更は影響しない。HomeContentView の API は不変。

- [ ] **Step 2: RootContentView を更新**

`App/AwaIro/RootContentView.swift`:

```swift
import AwaIroDomain
import AwaIroPresentation
import SwiftUI

struct RootContentView: View {
  let container: AppContainer
  @State private var path: [AppRoute] = []
  @State private var paletteSheetPresented = false
  @Environment(\.colorScheme) private var systemColorScheme

  var body: some View {
    let theme = SkyTheme(
      palette: container.themeStore.palette,
      mode: container.themeStore.mode,
      systemColorScheme: systemColorScheme
    )

    NavigationStack(path: $path) {
      HomeScreen(
        viewModel: container.makeHomeViewModel(),
        camera: container.camera,
        onCaptured: { url, takenAt in
          path.append(.memo(fileURL: url, takenAt: takenAt))
        },
        onTapGallery: { path.append(.gallery) },
        onTapMenu: { paletteSheetPresented = true }
      )
      .navigationBarHidden(true)
      .navigationDestination(for: AppRoute.self) { route in
        destinationView(for: route)
      }
    }
    .environment(\.skyTheme, theme)
    .preferredColorScheme(theme.mode == .system ? nil : (theme.mode == .dark ? .dark : .light))
    .task {
      await container.themeStore.load()
    }
    .sheet(isPresented: $paletteSheetPresented) {
      PaletteSheet(
        selectedPalette: container.themeStore.palette,
        selectedMode: container.themeStore.mode,
        onPickPalette: { p in Task { await container.themeStore.setPalette(p) } },
        onPickMode: { m in Task { await container.themeStore.setMode(m) } }
      )
      .skyTheme(theme)
      .presentationDetents([.medium])
    }
  }

  @ViewBuilder
  private func destinationView(for route: AppRoute) -> some View {
    switch route {
    case .memo(let fileURL, let takenAt):
      MemoScreen(
        viewModel: container.makeMemoViewModel(fileURL: fileURL, takenAt: takenAt),
        onFinished: { path.removeAll() }
      )
      .navigationBarHidden(true)

    case .gallery:
      GalleryScreen(
        viewModel: container.makeGalleryViewModel(),
        onTapPhoto: { id in path.append(.photoDetail(photoId: id)) },
        onTapBack: { path.removeLast() },
        onTapMenu: { paletteSheetPresented = true }
      )
      .navigationBarHidden(true)

    case .photoDetail(let id):
      PhotoDetailRoute(container: container, photoId: id)
        .navigationBarHidden(true)
    }
  }
}

/// Loader view that fetches the photo list + opens PhotoDetailScreen at the right initial id.
private struct PhotoDetailRoute: View {
  let container: AppContainer
  let photoId: UUID
  @State private var photos: [Photo] = []
  @State private var loaded = false

  var body: some View {
    Group {
      if loaded, !photos.isEmpty {
        PhotoDetailScreen(
          photos: photos,
          initialPhotoId: photoId,
          updateMemoFactory: { photo in container.makePhotoDetailViewModel(photo: photo) }
        )
      } else {
        ProgressView().tint(.white)
      }
    }
    .task {
      do {
        let all = try await container.developPhotoUseCase.execute()
        // Show only developed photos (G2 — undeveloped should not be reachable, but defensive)
        let now = Date()
        photos = all.filter { $0.isDeveloped(now: now) }
        loaded = true
      } catch {
        loaded = true
      }
    }
  }
}
```

- [ ] **Step 3: iOS Simulator ビルドが通ることを確認**

```bash
xcodebuild build -project App/AwaIro.xcodeproj -scheme AwaIro \
  -destination 'platform=iOS Simulator,name=iPhone 16 (AwaIro)'
```

Expected: `BUILD SUCCESSFUL`

- [ ] **Step 4: HomeScreen の既存 snapshot test が依然緑であることを確認**

```bash
swift test --package-path packages/AwaIroPresentation --filter HomeScreenSnapshotTests
```

Expected: 既存 5 件全 pass。HomeScreen のコンストラクタが変わったが、テストは `HomeContentView` を直接 driving しているので影響なし。

- [ ] **Step 5: コミット**

```bash
git add App/AwaIro/RootContentView.swift \
        packages/AwaIroPresentation/Sources/AwaIroPresentation/Home/HomeScreen.swift
git commit -m "feat(app): wire Gallery + PhotoDetail + PaletteSheet routes into RootContentView"
```

---

## Verification & Polish

### Task 24: Bubble pop animation + auto-tick (optional polish)

**Files:**
- Modify: `packages/AwaIroPresentation/Sources/AwaIroPresentation/Gallery/BubbleGalleryItem.swift`

- [ ] **Step 1: 浮遊アニメーションを BubbleGalleryItem に追加**

既存 `body` を `@State private var floatY: CGFloat = 0` で wrap、`.offset(y: floatY)` を Circle に当てる:

```swift
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
    .onAppear {
      withAnimation(.easeInOut(duration: Double.random(in: 4...8)).repeatForever(autoreverses: true)) {
        floatY = -8
      }
    }
  }

  private var remainingCopy: String {
    let secs = max(0, photo.remainingUntilDeveloped(now: now))
    let hours = Int(secs / 3600)
    return hours <= 0 ? "もうすぐ" : "あと\(hours)時間"
  }
}
```

> Note: snapshot tests は `onAppear` 前にレンダリングされる傾向があるので `floatY = 0` の初期値で記録される。スナップショットが flaky になる場合（`floatY` が偶発的に animation 途中で記録される）は、Step 2b の対処を施す。

- [ ] **Step 2: Snapshot 再 record + 通常実行で確認**

```bash
SNAPSHOTS_RECORDING=true swift test --package-path packages/AwaIroPresentation --filter GalleryScreenSnapshotTests
swift test --package-path packages/AwaIroPresentation --filter GalleryScreenSnapshotTests
```

Expected: 緑。

- [ ] **Step 2b: もし flaky なら animation を test 環境で無効化**

`BubbleGalleryItem.swift` の `onAppear` を以下に置き換え:

```swift
.onAppear {
  // Skip animation under XCTest / swift-testing snapshot harness for stability.
  if NSClassFromString("XCTestCase") != nil { return }
  withAnimation(.easeInOut(duration: Double.random(in: 4...8)).repeatForever(autoreverses: true)) {
    floatY = -8
  }
}
```

その後 snapshot を再 record + 通常実行 → 緑になることを確認。

- [ ] **Step 3: コミット**

```bash
git add packages/AwaIroPresentation/Sources/AwaIroPresentation/Gallery/BubbleGalleryItem.swift \
        packages/AwaIroPresentation/Tests/AwaIroPresentationTests/__Snapshots__/GalleryScreenSnapshotTests
git commit -m "feat(presentation): add float animation to BubbleGalleryItem"
```

---

### Task 25: iOS Simulator manual smoke test

**Files:** なし（手動テスト）

- [ ] **Step 1: `make verify` が緑であることを確認**

```bash
make verify
```

Expected: 全テスト緑 / lint 緑 / build 緑。

- [ ] **Step 2: iOS Simulator でアプリを起動し、以下シナリオを確認**

```bash
xcodebuild build -project App/AwaIro.xcodeproj -scheme AwaIro \
  -destination 'platform=iOS Simulator,name=iPhone 16 (AwaIro)'

xcrun simctl boot "iPhone 16 (AwaIro)" || true
xcrun simctl install "iPhone 16 (AwaIro)" build/Build/Products/Debug-iphonesimulator/AwaIro.app
xcrun simctl launch "iPhone 16 (AwaIro)" io.awairo.AwaIro
```

> 起動コマンドはプロジェクトのバンドル ID が異なる可能性あり。`xcrun simctl listapps "iPhone 16 (AwaIro)" | grep -i awairo` で確認。

- [ ] **Step 3: マニュアルチェックリスト**

- [ ] HomeScreen に「泡たち」ボタンと「メニュー」ボタンが表示される
- [ ] 「メニュー」ボタンをタップすると PaletteSheet が medium detent で出る
- [ ] 6 種類のパレットが選べて、選択状態がハイライトされる
- [ ] パレット切り替え後、シートを閉じても背景色が変わっている
- [ ] アプリを kill → 再起動して、選んだパレットが復元される
- [ ] 「泡たち」ボタンで GalleryScreen に遷移
- [ ] 写真がない状態では「まだ泡がありません」と表示
- [ ] 撮影済みなら泡が縦に並ぶ
- [ ] 24h 未経過の泡は半透明で「あと○時間」と表示
- [ ] 24h 経過した泡は中に写真が見える
- [ ] 現像済み泡をタップ → PhotoDetailScreen に遷移
- [ ] PhotoDetailScreen で写真がフルスクリーン、メモが見える
- [ ] 鉛筆アイコンタップでメモ編集モード、保存できる
- [ ] 左右スワイプで前後の写真に移動（複数枚ある時）
- [ ] シェアボタンが表示される（タップしても何もしない）
- [ ] 戻るジェスチャで Gallery に戻る、Home に戻る

問題があれば Task 25b として記録して直す。

- [ ] **Step 4: スクリーンショットを取って `docs/manual/phase-3-smoke-test.md` に貼る（任意）**

---

### Task 26: Phase 3 retro doc + README 更新

**Files:**
- Create: `docs/retros/2026-MM-DD-phase-3-retrospective.md` (実行日に応じて命名)
- Modify: `README.md`

- [ ] **Step 1: Phase 3 retro テンプレを書く**

`docs/retros/2026-MM-DD-phase-3-retrospective.md`:

```markdown
# Phase 3 Retrospective — Sprint 2 Develop (現像) iOS Native

**Date**: YYYY-MM-DD
**Phase**: 3 — Sprint 2 Develop iOS Native Implementation
**Outcome**: ✅ / ⚠️ / ❌

---

## Done

- [ ] DevelopPhotoUseCase + UpdateMemoUseCase
- [ ] Photo に developedAt / isDeveloped / remainingUntilDeveloped 追加
- [ ] DB migration v2 (developed_at column)
- [ ] PhotoRepositoryImpl 拡張（findAll/findById/updateMemo）
- [ ] SkyPalette + ThemeMode + ThemeRepository (UserDefaults)
- [ ] SkyTheme value type + EnvironmentKey
- [ ] ThemeStore @Observable
- [ ] GalleryScreen + GalleryViewModel + BubbleGalleryItem + Snapshot tests
- [ ] PhotoDetailScreen + PhotoDetailViewModel + TabView pager + Snapshot tests
- [ ] PaletteSheet + Snapshot tests
- [ ] BottomActionBar component
- [ ] RootContentView 拡張（gallery / photoDetail / palette sheet）
- [ ] G2 (翌日まで非表示) guardrail tests 緑
- [ ] G3 (数字なし) Snapshot guardrail 全画面で緑

## Keep / Problem / Try

### Keep
- 

### Problem
- 

### Try
- 

## ADR 候補
- 

## Phase 4 へのインプット
- 
```

- [ ] **Step 2: README の Phase 表を更新**

`README.md` の進捗セクションで Phase 3 を ✅ にマーク。

- [ ] **Step 3: コミット**

```bash
git add docs/retros/2026-*-phase-3-retrospective.md README.md
git commit -m "docs: Phase 3 retro + README 更新"
```

---

## Final Verification

### Task 27: Definition of Done — 全体チェック

- [ ] `make verify` 緑
- [ ] iOS Simulator 起動 + Task 25 manual smoke test 全項目 ✅
- [ ] G2 (DevelopPhotoUseCaseTests / PhotoTests) 緑
- [ ] G3 (Snapshot G3 guardrail in HomeScreen / GalleryScreen / PhotoDetailScreen) 緑
- [ ] Conventional Commit 全コミット完了（push は HITL — ユーザー承認後）
- [ ] Phase 3 retro doc 作成済み

完了したらユーザーに報告して `git push origin conversion/phase-2-record` の承認を取る。

---

## Notes for the Engineer

- **G1 (1日1枚)** は既に Phase 2 の `RecordPhotoUseCase` で守られている。Phase 3 では新規にロジックを足さない（developedAt 設定のみ）
- **G2 (翌日まで非表示)** は `Photo.isDeveloped(now:)` を View / VM が呼ぶことで守る。UseCase レベルでは filter しない（spec に合わせて undeveloped も gallery に出す）
- **G3 (数字なし)** は各画面の snapshot test で「いいね/フォロワー/閲覧/シェア数」等の文字列が出ないことを assert する
- **G4 (通知で促さない)** は Phase 3 でも変わらず — Push entitlements は不要
- **G5 (個人特定不能な位置情報)** は Phase 3 では位置情報を扱わないので影響なし

新しい外部依存は不要（`UserDefaults` で十分）。Package.resolved の変動なし。

DB migration v2 は HITL gate に該当（Task 9 でユーザー承認を取る）。

snapshot は flaky になりがち（フォント / dynamic type / colorScheme）。再現性が出ない場合は ADR 0006 「snapshot auto-record」の方針に従って、CI が自動 record するよう調整可能。Phase 3 内では手動 record で十分。
