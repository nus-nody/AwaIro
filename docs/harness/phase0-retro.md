# Phase 0 Retro — KMP→iOS Bootstrap

**Date:** 2026-05-04
**Participants:** nusnody, Orchestrator (Claude Opus 4.7)
**Phase 0 PR:** [#3](https://github.com/nus-nody/AwaIro/pull/3)
**Phase 0 commits:** 17 + 6 retro fixes = 23

## What worked

- **Plan→Execute 分離の威力**: spec → plan（17 tasks, 2152 行）を先に固めたことで、subagent dispatch で迷いが少なく、進行が速かった。
- **HITL hook の即時動作**: Task 15 完了直後から `git push` ブロックが効いた。実際に PR 作成時にも反応し、想定通りの動作を確認。
- **3 層自律度モデル + Trust Ladder**: HITL/HOTL/HOOTL の分類が「いつ止まるか/進むか」の判断を機械化できた。グレーゾーンが減った。
- **batch quality review の現実解**: SPM 4 パッケージのスキャフォールド（Tasks 2-5）は同型の作業なので、quality review を 1 回にまとめても品質を落とさず効率化できた。
- **Concept Guardrails の早期文書化**: Phase 1 でテスト実装に入る時点で「何を守るか」が既に決まっている状態にできた。
- **archive/kmp 戦略**: KMP コードの完全削除を躊躇なく実行できたのは、archive ブランチ + tag が GitHub 上で参照可能だったから。

## What didn't (friction points)

- **HITL hook の heredoc false positive**: commit message 本文に `git push` 等が入ると hook が誤反応。Task 15 implementer が `-F file` で回避し、その後 retro R2 で heredoc skip を実装。
- **Co-Authored-By trailer の抜け落ち**: `git commit -F file` で commit したとき、trailer をファイルに書き忘れて 1 コミットだけ trailer 抜けが発生（commit `423b97e`）。amend 規約があるため後付け修正せず、規約違反として記録。
- **Snapshot test の初回 record の煩雑さ**: Phase 0 では snapshot test 自体は未導入だが、Phase 1 で初回 record の運用フロー（`record: .all` 一時付与 → 削除 → commit）が摩擦点になりそう。test-engineer エージェントの責務に明記済み。
- **Subagent への context 渡し**: 各タスクで full task text を prompt に貼る必要があり、orchestrator 側の入力サイズが大きくなった。長期的には plan を section ごとに切り出す手法を検討。
- **swift-format 未導入**: Phase 0 中は swift-format がインストールされていなかったため `make verify` の lint が no-op だった。Phase 0 末で brew install + `--strict` 動作を確認、以降は本番動作。

## Trust Ladder decisions (論点 2)

| 操作 | Phase 0 末の判断 | 根拠 |
|------|--------------|------|
| HITL hook の `git push` ブロック | **HITL 維持** | 想定通り動作。bypass 機構で承認後の操作も実用的 |
| `swift-format` 自動適用（PostToolUse） | **保留**（Phase 1 で観察） | Phase 0 では未動作（swift-format 未 install）。Phase 1 で実走確認 → コード意味変更が一度でもあれば HOTL 昇格 |
| `Conventional Commit`（push 前）| **HOTL 維持** | trailer 抜け落ち事故が 1 件発生。Phase 1 の安定確認後に HOOTL 降格再検討 |
| `make verify` の自動実行（タスク完了時）| **HOTL → HOOTL に降格** | 決定論的・副作用なし・失敗時即検知。Phase 1 から各タスク完了時に黙って実行する |
| `git status` / `git log` 等 read 系 | **HOOTL 維持** | 想定通り |
| 新規 SPM 依存追加（初回）| **HITL 維持** | サプライチェーン。信頼ある依存元の routine update のみ将来 HOTL 検討 |

→ Gate Matrix を更新（`make verify` を HOOTL に追加）。

## Agent definitions added (論点 1)

当初 Phase 1 末で追加予定だった 3 役を、Phase 1 開始前に前倒しで作成:

- **test-engineer.md** (Sonnet, HOTL): Phase 1 Tasks 5 (GRDB integration test) / 9 (G3 guardrail snapshot) で実戦投入
- **devops.md** (Sonnet for design / Haiku for routine, HOTL): Tasks 11-12 (Xcode UI 操作支援) / 15 (Makefile + xcodebuild) で実戦投入
- **ux-designer.md** (Sonnet, HITL): Task 8 (HomeScreen 視覚デザイン) で実戦投入

ADR 0002 と README を「Phase 1+」表記から外し、6 役全て即時利用可能に。

## Spec / ADR updates (論点 3)

- **ADR 0004 — Dependency pinning policy**（新規追加）: GRDB と swift-snapshot-testing の Phase 1 投入を機に、依存追加時のバージョン戦略（`from:` 範囲指定 vs `exact:` 固定）を文書化。
- HITL_BYPASS env var の運用は ADR 0002 への補足（`docs/harness/gate-matrix.md` の bypass セクション）で十分とした。

## Phase 1 entry blockers

なし。以下が整っている:

- ✅ 6 エージェント定義
- ✅ Hooks 改修済み（heredoc skip / BYPASS / 拡張パターン / Edit gate）
- ✅ swift-format 本番動作
- ✅ Phase 1 plan（17 tasks, 2180 行）commit 済 / push 済
- ✅ ADR 0004 (dependency pinning) 追加済
- ✅ make verify 緑

Phase 1 着手準備完了。

## Process improvements for Phase 1

- **subagent dispatch の prompt 軽量化**: Phase 1 は 17 タスクと多めなので、共通 context を 1 度だけ詰める＋タスク固有部分だけ展開する方式を試す
- **batch quality review の閾値**: Phase 0 では 3 タスク（SPM 3 パッケージ）を batch にしたが、Phase 1 では Domain 3 タスク（Tasks 1-3）を 1 batch にできるか検討
- **Phase 1 末 retro のタイミング**: Phase 1 完了直後に同形式で retro。Phase 2 plan 起こしの前に挟む

## References

- Spec: [2026-05-04-kmp-to-ios-conversion-design.md](../superpowers/specs/2026-05-04-kmp-to-ios-conversion-design.md)
- Phase 0 plan: [2026-05-04-phase-0-bootstrap.md](../superpowers/plans/2026-05-04-phase-0-bootstrap.md)
- Phase 1 plan: [2026-05-04-phase-1-walking-skeleton.md](../superpowers/plans/2026-05-04-phase-1-walking-skeleton.md)
- ADR 0002 (multi-agent harness): [0002-multi-agent-harness.md](../adr/0002-multi-agent-harness.md)
- ADR 0004 (dependency pinning): [0004-dependency-pinning-policy.md](../adr/0004-dependency-pinning-policy.md)
- Gate Matrix: [gate-matrix.md](gate-matrix.md)
