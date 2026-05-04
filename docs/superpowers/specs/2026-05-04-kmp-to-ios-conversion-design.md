---
type: design
tags: [conversion, ios, harness, multi-agent, hitl, hotl]
created: 2026-05-04
updated: 2026-05-04
status: approved
---

# Design — KMP → iOS Native Conversion + Multi-Agent Development Harness

## Context

AwaIro はこれまで Kotlin Multiplatform + Compose Multiplatform で開発してきた（Sprint 0 基盤 / Sprint 1 記録 マージ済み、Sprint 2 現像 計画済 未実装）。テスト容易性とイテレーション速度に課題があり、iOS 専用ネイティブ実装に転換する。同時に、複数の専門エージェントが協調する開発ハーネスを整備し、HITL（Human In The Loop）/ HOTL（Human On The Loop）/ HOOTL（Human Out Of The Loop）の 3 層自律度モデルで境界を明確にする。Trust Ladder により操作ごとに段階的な昇降格を運用する。

将来 Android 復活の可能性があるため、Domain / Data 層は iOS フレームワーク非依存に保ち、永続化は SQL ベースで Android Room へ移行しやすい構造を選ぶ。

## Goals

- iOS 専用ネイティブ（SwiftUI + Swift Concurrency）への完全移行
- 6 専門エージェントが協調する開発ハーネスの整備
- HITL / HOTL / HOOTL の 3 層自律度ゲート表による「不可逆性 × 影響範囲 × 決定論性」での機械的判定 + Trust Ladder による昇降格運用
- Sprint 1（記録）の前進ポート完了 / Sprint 2（現像）のネイティブ実装完了
- Android 復活パスを設計上残す（Domain/Data の FW 非依存、SQL 永続化）

## Non-Goals

- Sprint 1 既存コードの機械的 1:1 ポート（SwiftUI 自然形に再構築する）
- Android 即時対応（あくまで「将来選択肢」として設計の純度を保つ）
- サードパーティ DI / 状態管理ライブラリの導入（標準のみで構築）
- 既存 KMP コードの完全削除（`archive/kmp` ブランチに保管）

## Conversion Strategy — Forward Port

KMP コードは `archive/kmp` ブランチに保管後、main から物理削除する。Sprint 1 の機能仕様（spec）は流用しつつ、実装は SwiftUI / Swift Concurrency / @Observable の自然形に再構築する。`expect/actual` 抽象や Koin DI は SPM パッケージ境界 + init injection に置き換える。

設計ドキュメント（concept / Sprint 1 spec / Sprint 2 spec）はプラットフォーム中立を保ち、引き続き活用する。Sprint 2 plan のみ iOS 文脈で再評価し、必要なら書き直す。

## Architecture — Clean Arch with SPM Modules

### Module Layout

```
AwaIro.xcworkspace
├── App                           # Xcode App Target
│   ├── @main, AwaIroApp.swift
│   ├── ContentView.swift (NavigationStack root)
│   └── AppContainer.swift        # Composition Root（手書き DI）
└── packages/
    ├── AwaIroDomain/             # Pure Swift, no UIKit/SwiftUI import
    │   ├── Models/               # Photo, Memo (value types)
    │   ├── Repositories/         # protocols
    │   └── UseCases/             # RecordPhoto, GetTodayPhoto, DevelopPhoto, etc.
    ├── AwaIroData/               # GRDB, file IO, repo impls
    │   ├── Database/             # DatabaseFactory, migrations
    │   ├── Repositories/         # PhotoRepositoryImpl
    │   └── Mappers/              # Row ↔ Domain
    ├── AwaIroPlatform/           # 端末依存 API
    │   ├── Camera/               # CameraController (actor), AVFoundation
    │   ├── Effects/              # BubbleDistortion (Metal shader)
    │   ├── Files/                # FilePathProvider
    │   ├── Share/                # ShareService
    │   └── Lifecycle/            # FirstLaunchGate
    └── AwaIroPresentation/       # SwiftUI Views + @Observable ViewModels
        ├── Home/                 # HomeScreen + HomeViewModel
        ├── Memo/                 # MemoScreen + MemoViewModel
        ├── Develop/              # DevelopScreen + DevelopViewModel (Sprint 2)
        └── Components/           # BubbleCameraView 等
```

### Dependency Direction

```
App → Presentation → (Domain ← Data, Platform)
```

- Domain は他モジュールに依存しない（Pure Swift）
- Data / Platform は Domain の protocol を実装（依存性逆転）
- Presentation は Domain と Platform に依存（UseCase 経由 + Camera 等）
- App は全モジュールに依存し Composition Root として束ねる

### Why this structure

- Domain を SwiftUI / UIKit から物理隔離 → Android 復活時はパッケージ単位で Kotlin 化すれば済む
- Pure Swift Domain は単体テストが軽量・高速
- SPM パッケージ境界が「設計の意図」を強制する（import できない＝依存違反）

## Technology Stack

| レイヤ | 採用 | 理由 |
|--------|------|------|
| UI | SwiftUI + 必要時 `UIViewRepresentable` | カメラプレビュー（AVCaptureVideoPreviewLayer）だけ UIKit 経由 |
| 状態管理 | `@Observable` (Swift 5.9+) | KMP の StateFlow → `@Observable` が最も自然 |
| 並行処理 | Swift Concurrency（async/await + actor） | Camera / File を actor 隔離してテスタビリティ確保 |
| アーキテクチャ | Clean Arch 3層 | 既存方針継続 / Android 移植時にレイヤ対応がそのまま効く |
| DI | Init Injection + 手書き `AppContainer` | サードパーティ不要 / `@Observable` と相性良 |
| 永続化 | **GRDB.swift（SQL）** | SQLDelight と最も近い / Android Room 移行しやすい |
| テスト | Swift Testing + swift-snapshot-testing | 新規は Swift Testing / SwiftUI は Snapshot |
| 画像 | 標準 `AsyncImage` + `ImageRenderer` | サードパーティ不要 |

ADR `0001-stack-decision.md` で代替案（SwiftData / Core Data / TCA / XCTest）の検討経緯を記録する。

## Multi-Agent Harness

### Agent Roles & Models

| # | 役割 | モデル | 既定モード | 主担当 |
|---|------|--------|----------|-------|
| 1 | iOS Architect（Product 兼務）| Opus 4.7 | HITL | アーキ判断 / ADR / 設計レビュー / コンセプト守護 |
| 2 | iOS Engineer | Sonnet 4.6 | HOTL | SwiftUI / Swift Concurrency 実装 / TDD |
| 3 | Test Engineer | Sonnet 4.6 | HOTL | テスト戦略 / Swift Testing / Snapshot / Red→Green |
| 4 | Code Reviewer | Opus 4.7 | HOTL（重大時 HITL）| 規約 / セキュリティ / 性能 / 読みやすさ |
| 5 | Build/DevOps Engineer | Sonnet 4.6（設計）/ Haiku 4.5（定常）| HOTL | Makefile / xcodebuild / Xcode MCP / CI |
| 6 | UX Designer (Light) | Sonnet 4.6 | HITL | `design:*` プラグインスキル駆動 / SwiftUI Preview / Snapshot 雛形 |
| — | Orchestrator（主担当） | Opus 4.7 (1M) | — | 全体統合 / 役間調整 / 優先順位判断 |

### Agent Definition Files

`.claude/agents/<name>.md` 形式。frontmatter:

```yaml
---
name: ios-architect
description: アーキテクチャ判断、ADR ドラフト、設計レビュー時に dispatch
model: opus
tools: Read, Grep, Glob, Write, Edit, Bash
---

<role specification, prompt, examples>
```

Phase 0 では `architect.md` / `engineer.md` / `reviewer.md` の 3 ファイルを作成。残り 3 役（test-engineer / devops / ux-designer）は Phase 1 末の retro 結果を反映してから作成。

### Hooks (`.claude/settings.json`)

| Hook | Trigger | Action |
|------|---------|--------|
| `PostToolUse` | Write/Edit on `*.swift` | `swift-format` 自動適用 |
| `Stop` | セッション終了時 | 未コミット差分があれば `git status` 表示 |
| `PreToolUse` | Bash matching `git push\|git merge\|rm -rf` | 強制 HITL 確認プロンプト |

### Makefile Targets

```
make bootstrap     # SPM resolve, simulator boot
make build         # xcodebuild -workspace AwaIro.xcworkspace -scheme App
make test          # xcodebuild test 全パッケージ
make test-snapshot # snapshot tests のみ
make lint          # swift-format --lint --recursive
make verify        # build + test + lint（DoD チェック）
make archive-kmp   # Phase 0 一回限りの退却ヘルパ（dry-run 既定。実削除は ARCHIVE_CONFIRM=1 + HITL 承認後）
```

`make archive-kmp` は破壊的操作のガード付きラッパ。デフォルトは dry-run で、削除候補ファイル一覧と `archive/kmp` ブランチ作成プランを表示するのみ。実削除は `ARCHIVE_CONFIRM=1 make archive-kmp` 明示指定 + HITL 承認時のみ実行。

### ADR (`docs/adr/`)

`NNNN-slug.md` 形式。Phase 0 で起こす 3 本:

- `0001-stack-decision.md` — UI/State/Persistence/Test 採用の根拠と代替検討
- `0002-multi-agent-harness.md` — 役割・モデル・ゲート方針の根拠
- `0003-spm-module-boundaries.md` — パッケージ境界・依存方向の根拠

以後、技術選択を変更するたびに新規 ADR を追加する。Android 復活時は `0001` の "Alternatives Considered" が参照点になる。

### Concept Guardrails (`docs/concept-guardrails.md` + `*GuardrailTests.swift`)

不変条件をテストに落とし込み、Reviewer が照合する:

| Guardrail | テスト |
|-----------|--------|
| 1日1枚 | `RecordPhotoUseCaseTests.testSecondPhotoSameDayReturnsAlreadyRecorded` |
| 翌日まで非表示 | `DevelopUseCaseTests.testCanDevelopFalseWithin24h` |
| 数字なし | `HomeScreenSnapshotTests` で「いいね数」「フォロワー」等の文字列が無いことを assert |
| 通知で促さない | `InfoPlistGuardrailTests` で Push 系 entitlements 不在を assert |
| 個人特定不能な位置情報 | `LocationServiceTests.testNeverStoresExactCoordinates`（Sprint 3 想定）|

### Autonomy Gate Matrix — HITL / HOTL / HOOTL (`docs/harness/gate-matrix.md`)

3 層モデルで「不可逆性 × 影響範囲 × 決定論性」を機械的に判定する。

| 区分 | 意味 | 操作 | ゲート |
|------|------|------|-------|
| 🔴 **HITL** | Human In The Loop — 都度承認 | `git push` / PR 作成 / PR merge | 都度承認 |
| 🔴 HITL | | branch 削除（特に main 系）| 都度承認 |
| 🔴 HITL | | ファイル一括削除（>5 ファイル or >100 行）| 都度承認 |
| 🔴 HITL | | DB スキーマ変更 / マイグレーション | 都度承認 |
| 🔴 HITL | | Xcode project / Info.plist / entitlements 変更 | 都度承認 |
| 🔴 HITL | | 依存追加/削除（Package.resolved 変動）| 都度承認 |
| 🔴 HITL | | ADR 確定 / Concept Guardrail 変更 | 都度承認 |
| 🟡 **HOTL** | Human On The Loop — 自動進行・差分通知 | ファイル新規/編集（Domain/Data/Presentation 配下）| 自動進行・差分通知 |
| 🟡 HOTL | | テスト作成・実行 / Snapshot 記録 | 自動進行 |
| 🟡 HOTL | | ローカルビルド（simulator）| 自動進行 |
| 🟡 HOTL | | Conventional Commit（push 前）| 自動進行（reset で巻き戻せるため）|
| 🟡 HOTL | | Reviewer の通常指摘 | 自動進行 |
| 🟢 **HOOTL** | Human Out Of The Loop — 完全自律・通知なし | Read 系（Read / Glob / Grep）| ゲートなし・通知なし |
| 🟢 HOOTL | | `swift-format` / `swift-format --fix`（hook 内） | ゲートなし・通知なし |
| 🟢 HOOTL | | SPM resolve（既存依存の解決）| ゲートなし・通知なし |
| 🟢 HOOTL | | Snapshot 差分の表示（記録は HOTL）| ゲートなし・通知なし |

#### HOOTL 適格基準

操作を HOOTL に分類する条件（**全て**満たす必要あり）:

1. **完全に決定論的** — 同入力なら同出力（フォーマッタ、lint、Read）
2. **ファイル変更が局所的かつ自動可逆** — 再実行で正規化できる（swift-format は再適用で同じ結果）
3. **外部状態に影響しない** — push / API 呼び出し / 通知 / 共有リソース変更 なし
4. **失敗が即検知できる** — 失敗しても次工程の `make verify` で必ず引っかかる、または操作自体が no-op

1つでも崩れたら HOTL 以上に分類する。

#### 自動 HITL 昇格トリガー（HOTL → HITL）

HOTL モード中に以下が発火したら停止して人を呼ぶ:

- ローカルビルドが連続2回失敗
- Reviewer が `blocker` 相当の重大指摘
- Concept Guardrail テストが赤
- スキーマ／ビルド設定／entitlements ファイルへの差分検出
- セキュリティ系の発見（鍵らしき文字列、ハードコードされた秘密、危険な権限要求）
- スコープ外の変更（plan に無いファイルへの編集）

#### 自動 HOTL 降格トリガー（HOOTL → HOTL）

HOOTL 操作で以下が発火したら、その操作を HOTL に降格して人に通知:

- HOOTL 操作が予期せぬ振る舞いを示した（例: swift-format がコード意味を変えた、または diff が想定より大きい）
- HOOTL hook で複数ファイルにまたがる不整合を検出
- セキュリティスキャン（HOOTL の Read 系の一種）で秘密情報を検出
- HOOTL 操作の連続失敗

#### Trust Ladder — 自律度の昇降格パス

新規操作はまず HITL から始め、安定運用が確認できたら段階的に降格する。逆も然り。

```
[新規操作 / 高リスク]  HITL  ←──┐
                        │       │ 問題発生で昇格
                        ↓ 安定運用で降格
                       HOTL  ←──┤
                        │       │ 問題発生で昇格
                        ↓ 長期安定で降格
                      HOOTL ────┘
```

**判断は各 Phase 末の retro で実施:**
- Phase 0 末: Phase 1 走行に向けて昇降格を判定
- Phase 1 末: 残り 3 役の追加と同時に gate 表を改訂
- Phase 2/3 末: 累積知見で再評価

**昇降格の例（参考）:**
- Reviewer の trivial diff（typo 修正、import 順正規化）への approve → 安定後に HOTL → HOOTL
- 新規 SPM 依存追加 → 初期は HITL、信頼ある依存元（Apple, point-free 等）の routine update は HOTL に降格可能
- swift-format の挙動が一度でもコード意味を変えたら → HOOTL → HOTL に昇格

### Definition of Done (タスク粒度)

各タスク完了の必要十分条件:

1. テストが緑（`make test`）
2. Reviewer エージェントの承認
3. `make verify` 通過（build + test + lint）
4. spec の acceptance criteria を満たす
5. Conventional Commit 完了（push は HITL）

### Pre-mortem Trigger

以下に該当する変更は、実装前に「5行の "何が壊れうるか"」を必須記載:

- DB スキーマ変更
- アプリエントリ（`@main`、`AwaIroApp`、`ContentView` ルート）への変更
- ビルド設定（Xcode project, Info.plist, entitlements, Package.swift）への変更
- ハーネス自体への変更（hooks, gate matrix, agent 定義）

## Phased Execution Plan

### Phase 0 — Harness Bootstrap（見積 1〜2 セッション）

1. `archive/kmp` ブランチ作成 → GitHub push **[HITL]**
2. main から KMP ファイル削除 commit **[HITL]**
3. SPM workspace + 4 パッケージ雛形作成
4. `.claude/agents/` 3 ファイル: `architect.md` / `engineer.md` / `reviewer.md`
5. `.claude/settings.json` 最小 hooks
6. `Makefile` 骨組み
7. ADR 3 本: `0001-stack-decision.md` / `0002-multi-agent-harness.md` / `0003-spm-module-boundaries.md`
8. `docs/concept-guardrails.md` 雛形
9. `docs/harness/gate-matrix.md` 雛形
10. README を iOS-only 前提に更新

**Done 条件:** `make verify` が空テストで緑 / 3 ADR commit 済 / `archive/kmp` GitHub にあり / main から KMP 消失 / 上記ドキュメント全て commit 済。

### Phase 1 — Walking Skeleton（見積 2〜3 セッション）

HomeScreen の縦串だけポート:

- Domain: `Photo` value type, `PhotoRepository` protocol, `GetTodayPhotoUseCase`
- Data: `PhotoRepositoryImpl(GRDB)`, migration v1, `Photo` table
- Platform: 最小 `FilePathProvider`
- Presentation: `HomeScreen` + `HomeViewModel`, ナビゲーション枠
- Test: `GetTodayPhotoUseCaseTests`（in-memory GRDB）/ `HomeScreenSnapshotTests`（数字なし guardrail 含む）

**Done 条件:** Simulator で起動して HomeScreen が表示 / テスト全緑 / `docs/harness/phase1-retro.md` に摩擦点記録 → 残り 3 役（test-engineer / devops / ux-designer）と hooks/gate を肉付け。

### Phase 2 — Sprint 1 Complete Port（見積 3〜5 セッション）

Camera + MemoScreen + RecordPhotoUseCase + BubbleDistortion をポート:

- Camera: AVFoundation actor で隔離、`UIViewRepresentable` でプレビュー
- MemoScreen: 既存 spec 流用、@Observable VM
- RecordPhoto: 1日1枚 guardrail を usecase レベルで強制
- BubbleDistortion: Metal shader 移植（重い場合は spike 後 Core Image 代替を ADR 化）

Test Engineer 役を本格起用、全画面 snapshot を記録。

**Done 条件:** Sprint 1 機能が iOS Simulator で動作 / 全画面 snapshot 取得 / Reviewer pass / Concept Guardrail 全緑。

### Phase 3 — Sprint 2 Develop Native Implementation（見積 5〜8 セッション）

既存の 19 タスク TDD plan（`docs/superpowers/plans/2026-05-02-sprint-2-develop.md`）を Swift 文脈で再評価:

- KMP 固有の項目（expect/actual、Koin、SQLDelight 関連）を間引く
- iOS 固有の追加（Snapshot 増強、UIKit 統合点）を補う
- 新 plan を `docs/superpowers/plans/2026-MM-DD-sprint-2-develop-ios.md` に書き直してから着手

**Done 条件:** Sprint 2 機能（現像）が iOS Simulator で動作 / Concept Guardrail "翌日まで非表示" 緑 / Reviewer pass。

## Risks & Mitigations

| リスク | 軽減策 |
|--------|-------|
| BubbleDistortion の Metal shader 移植が想定より重い | Phase 2 で spike を許可、最悪 Core Image フィルタ代替を ADR 化 |
| GRDB と SQLDelight の SQL 方言差 | Phase 1 のミニ migration で動作確認、差異を ADR に記録 |
| Snapshot テストが flaky（フォント・カラースキーム）| iPhone 15 / iOS 17.x simulator に固定、ライト/ダーク両方記録 |
| エージェント役割が形骸化 | Phase 1 末の retro で削減/統合判断 |
| Sprint 2 spec が KMP 前提 | Phase 3 入口で再評価、変更箇所を delta 文書化 |
| Xcode MCP の挙動学習不足 | Phase 0 で軽く触り、devops エージェント定義に経験則を反映 |
| 自動 HITL 昇格トリガーが過剰発火 | Phase 1 末の retro で閾値（連続失敗回数等）を調整 |
| KMP archival ブランチが壊れる | Phase 0 で `git push origin archive/kmp` を確認、tag も付与（`archive/kmp-v1.0.0`）|

## Acceptance Criteria — Conversion 全体の DoD

- [ ] `archive/kmp` ブランチが GitHub にあり、tag 付与済み
- [ ] main に Kotlin / Gradle / Compose ファイル一切なし
- [ ] `make verify` が緑
- [ ] Sprint 1 機能（記録）が iOS Simulator で動作
- [ ] Sprint 2 機能（現像）が iOS Simulator で動作
- [ ] ADR 6 本以上 / Concept Guardrail テスト 5 本以上 / Gate Matrix 文書 あり
- [ ] エージェント定義 6 ファイル / Makefile / Hooks 整備済み
- [ ] README が iOS-only 前提に更新

## Open Questions

- なし（質問1〜7で全て解決）

## Related

- [AwaIro Concept](../../../AwaIro_Concept.md)
- [Sprint 1 Record Spec](2026-04-25-sprint-1-record-design.md)
- [Sprint 2 Develop Spec](2026-05-02-sprint-2-develop-design.md)
- [Sprint 2 Develop Plan (KMP)](../plans/2026-05-02-sprint-2-develop.md) — Phase 3 で iOS 版に書き直し
