# AwaIro — Project Conventions for Claude Code

> このファイルは Claude Code が常時読み込むプロジェクト規約。冗長になりすぎないよう要点のみ。

## What this project is

iOS ネイティブの感情記録アプリ。1日1枚だけ撮れる、翌日まで見られない。コンセプトは [AwaIro_Concept.md](AwaIro_Concept.md)、Android 復活の可能性を残しつつ iOS 専用で開発中。

## Tech stack

SwiftUI + `@Observable` + Swift Concurrency / Clean Architecture 3 層 / Swift Package Manager 4 packages / GRDB.swift（SQL 永続化）/ Swift Testing + swift-snapshot-testing。詳細は [ADR 0001](docs/adr/0001-stack-decision.md)。

**触ってはいけない原則:**
- **AwaIroDomain は Pure Swift**: UIKit / SwiftUI / AVFoundation / Foundation 以外の iOS フレームワーク import 禁止（Android 移植性のため）
- **依存方向**: App → Presentation → (Domain ← Data, Platform)。逆流は ADR 0003 違反

## Definition of Done (per task)

1. `make verify` 緑（build + test + lint）
2. Swift Testing で TDD（test → fail → impl → pass）
3. Conventional Commit でコミット（`feat(domain): ...`, `docs(adr): ...` etc.）
4. Concept Guardrail に該当する変更は対応テストが緑

## Concept Guardrails — 必ず守る不変条件

詳細は [docs/concept-guardrails.md](docs/concept-guardrails.md)。要約:

- **G1**: 1日1枚（同日2枚目は UseCase で reject）
- **G2**: 翌日まで非表示（撮影 +24h 未満は現像不可）
- **G3**: 数字なし（いいね数・フォロワー数等を View に出さない）
- **G4**: 通知で促さない（Push entitlements 不要）
- **G5**: 行政区レベル位置のみ（緯度経度は保存しない）

これらに反する設計・実装は HITL に escalate して人と議論する。

## HITL / HOTL / HOOTL — 自律度ゲート

詳細は [docs/harness/gate-matrix.md](docs/harness/gate-matrix.md)。エージェントが「迷わず動ける」ためのルール:

- 🔴 **HITL** (Human In The Loop): `git push` / PR 操作 / branch 削除 / 一括削除 / DB schema / Xcode project / 依存追加 / ADR 確定 → **都度承認**
- 🟡 **HOTL** (Human On The Loop): ファイル編集 / テスト / build / commit（push 前）→ 自動進行・差分通知
- 🟢 **HOOTL** (Human Out Of The Loop): Read 系 / swift-format / SPM resolve → 完全自律

ユーザーが既に明示的に承認した HITL 操作は `HITL_BYPASS=1 <command>` で hook を素通りできる（hook script `hitl-bash-gate.sh` 参照）。

## Multi-agent harness

専門エージェントを `.claude/agents/<name>.md` で定義。Orchestrator が `Agent` ツールで `subagent_type` 指定で dispatch。Phase 1 開始前に 6 役全部揃った:

- **architect** (Opus, HITL): アーキ判断 / ADR / Concept Guardrail 守護
- **engineer** (Sonnet, HOTL): SwiftUI / Swift Concurrency 実装 / TDD
- **reviewer** (Opus, HOTL→HITL escalation): バグ・セキュリティ・規約・Guardrail 照合
- **test-engineer** (Sonnet, HOTL): テスト戦略 / Swift Testing / Snapshot 設計
- **devops** (Sonnet/Haiku, HOTL): Makefile / xcodebuild / CI / Hooks 保守
- **ux-designer** (Sonnet, HITL): SwiftUI 視覚デザイン / `design:*` プラグインスキル駆動

詳細は [ADR 0002](docs/adr/0002-multi-agent-harness.md)。

### ⚠️ Subagent 利用上の注意

`.claude/agents/*.md` のカスタム subagent_type は **Claude Code セッション開始時に load される**。**実行中のセッション内で新規追加・編集した agent 定義は次セッションまで反映されない**。

- 新規 agent を追加した場合、即座に dispatch したいなら `Agent(subagent_type: "general-purpose", model: <choice>, prompt: <agent定義をprompt先頭に貼り付け>)` で代替可能
- 既存 agent の定義変更も同様 — 反映には Claude Code 再起動が要る

## Build & test

```
make verify     # DoD チェック (build + test + lint)
make build      # SPM 4 packages を build
make test       # SPM 4 packages を test
make lint       # swift-format --lint (未インストールなら no-op)
make help       # 全ターゲット
```

## Commit conventions

- **形式**: Conventional Commits（`feat(scope): ...` / `fix(scope): ...` / `docs(scope): ...` / `chore(scope): ...` / `build: ...` / `refactor(scope): ...`）
- **scope**: `domain`, `data`, `platform`, `presentation`, `harness`, `adr`, `conversion` 等
- **trailer**: `Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>`
- **push しない**: ローカル commit は HOTL、push は HITL

## Spec / Plan の場所

- 設計: [docs/superpowers/specs/](docs/superpowers/specs/)
- 実装計画: [docs/superpowers/plans/](docs/superpowers/plans/)
- ADR: [docs/adr/](docs/adr/)

新しい spec / plan を書くときは `YYYY-MM-DD-<slug>.md` 形式で。

## Tools available

- Xcode 26 / Swift 6 / Swift Testing
- jq (`/usr/bin/jq`)
- gh CLI（GitHub 操作）
- (任意) swift-format（`brew install swift-format`）

## Swift 落とし穴（過去に踏んだ事例から）

### `resources:` の path 指定は file 単位で

`.target(name: ..., resources: [.process("Dir")])` は `Dir/` 配下の **すべて** をリソース扱いにする — `.swift` も Source ではなく Resource として扱われ、コンパイルされない。Metal shader (`.metal`) のような特定ファイルだけ bundle したい時は file 名まで指定:

```swift
resources: [.process("Effects/BubbleDistortion.metal")]
```

Phase 2 で `extension View { public func bubbleDistortion }` が "value has no member" エラーになった真の原因はこれだった（extension visibility ではない）。

### swift-format の `NoAccessLevelOnExtensionDeclaration` ルール

swift-format（既定）は `public extension X { func foo() }` を **error として flag** する。代わりに `extension X { public func foo() }` を強制する:

```swift
// ❌ swift-format error
public extension View {
    func foo() { }
}

// ✅ accepted
extension View {
    public func foo() { }
}
```

両者とも cross-module visibility は同じ（`public func` のメンバー側 modifier が効く）。`make lint` 通過のために後者を使う。

### iOS-only コードのビルド検証

`#if canImport(UIKit)` で囲った関数は macOS swift build ではスキップされる。新規 public API（特に SwiftUI ViewModifier 等）を追加したら、必ず iOS build を 1 回通すこと:

```bash
xcodebuild build -project App/AwaIro.xcodeproj -scheme AwaIro \
  -destination 'platform=iOS Simulator,name=iPhone 16 (AwaIro)'
```

`make test-ios` でカバーされるが、新 API 追加直後に手動で 1 回確認するのが安全。

### Apple framework を `actor` で wrap する時

`actor` の init から `@MainActor` 隔離された stored property に直接書き込めない（Swift 6 strict concurrency が拒否）。Apple の framework 型（`AVCaptureSession`, `AVCaptureVideoPreviewLayer` 等）は **多くが thread-safe** なので、actor ではなく `final class @unchecked Sendable + @MainActor init` で wrap する方が現実的（Phase 2 ADR 0007 参照）。

### Subagent dispatch のサイズ感

Phase 2 で 1 dispatch = 5 task の subagent が 2 度途中終了した。**1 dispatch あたり 2-3 task max** を目安に。タスクが 5+ ある時は 2 batch に分ける。subagent が中断したら git status で実状態を確認し、必要なら orchestrator が引き継ぐ（state がクリーンなら拾える）。

## やってはいけないこと

- Domain 層への iOS フレームワーク import
- ADR / Concept Guardrail を独断で変更
- `git push` を user 承認なしで実行
- 新規依存追加を user 承認なしで実行
- 「動いたから commit」する前に `make verify` を実行しない
- 機械的 1:1 KMP ポート（SwiftUI / Swift Concurrency の自然形に再構築する）
- `actor` で `@MainActor` プロパティを持つ Apple framework wrap（`final class` を検討、ADR 0007）
- `.process("DirName")` で `.swift` を含むディレクトリを指定（file 単位で specify する）
