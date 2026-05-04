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

専門エージェントを `.claude/agents/<name>.md` で定義。Orchestrator が `Agent` ツールで `subagent_type` 指定で dispatch。Phase 0 時点の役割:

- **architect** (Opus, HITL): アーキ判断 / ADR / Concept Guardrail 守護
- **engineer** (Sonnet, HOTL): SwiftUI / Swift Concurrency 実装 / TDD
- **reviewer** (Opus, HOTL→HITL escalation): バグ・セキュリティ・規約・Guardrail 照合

Phase 1 末で **test-engineer / devops / ux-designer** を追加予定。詳細は [ADR 0002](docs/adr/0002-multi-agent-harness.md)。

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

## やってはいけないこと

- Domain 層への iOS フレームワーク import
- ADR / Concept Guardrail を独断で変更
- `git push` を user 承認なしで実行
- 新規依存追加を user 承認なしで実行
- 「動いたから commit」する前に `make verify` を実行しない
- 機械的 1:1 KMP ポート（SwiftUI / Swift Concurrency の自然形に再構築する）
