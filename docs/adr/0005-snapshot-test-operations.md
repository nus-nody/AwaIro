# ADR 0005 — Snapshot Test Operations Policy

- Status: Accepted
- Date: 2026-05-04
- Deciders: nusnody, Orchestrator (Claude Opus 4.7)

## Context

Phase 1 で `swift-snapshot-testing` を導入し HomeScreen の snapshot test 3 件を稼働させた。Phase 2 では Camera プレビュー / 泡の歪み / MemoScreen / 撮影成功画面など、視覚要素のある画面が一気に増える。Snapshot 数が膨らむと:

- 初回 record の運用が分散すると review 漏れが起きる
- device / OS / フォントの揺らぎで flaky になる
- PR レビュー時に「画像差分が多すぎてレビュー疲れ」が発生する

Phase 1 retro で Task 9 implementer は `record:` API の探索に時間を要し、最終的に iPhone 15 (plan) → iPhone X (config) + iPhone 16 (実 simulator) で運用を確立した。この運用知見と Phase 2+ の予防策をポリシー化する。

## Decision

### 1. Device fixture（snapshot を取るデバイス）

スナップショットは **以下に限定**して取る:

- `ViewImageConfig.iPhoneX(.portrait)` — 375×812pt @3x（library 上限内で最も近代的）
- 実 simulator は **iPhone 16 (Booted) 系** を使う（iPhone 17 系も可、命名は `iPhone 16` ベースで統一）

将来 `swift-snapshot-testing` が iPhone 15 / 16 用 `ViewImageConfig` を出したら ADR で更新する。

ライト / ダーク両方を撮るのは **コンセプト上ダーク優先** のため当面ダークのみ。ライトテーマ snapshot は YAGNI として保留。

### 2. Recording cycle（新規 snapshot の追加手順）

新しい snapshot test を追加するときは:

1. `withSnapshotTesting(record: .all) { ... }` ブロックでテスト本体を囲む（または assertSnapshot 個別の `record:` 引数）
2. `make test-snapshot` を 1 回実行 → 画像が `__Snapshots__/` に書き出される
3. **画像を目視確認**（diff tool / Finder Quick Look）
   - 期待した状態が正しく描画されているか
   - フォント / レイアウト / 配色がコンセプトに沿っているか
   - G3 違反（数字表示）が混入していないか
4. `record: .all` を削除し、再度 `make test-snapshot` で verify 緑を確認
5. test ファイル + `__Snapshots__/*.png` を 1 commit にまとめる
6. commit message に「初回 record / 目視確認済」を明記

### 3. Verification cycle（既存 snapshot の検証）

通常の test 実行（`make test-snapshot` / `make verify`）は **verify モード**:

- 既存の `__Snapshots__/*.png` と現在のレンダ結果を pixel diff
- 1 pixel でも違うと失敗（library default）
- 失敗時は `Tests/.../Failures/` に diff 画像が出る → これも目視で「不可避な変更か / regression か」判断

### 4. PR review of new/changed snapshots

PR に snapshot 画像の追加/変更が含まれる場合:

- **Reviewer エージェントは画像を visually 確認できない** ため、人（ユーザー）の目視承認を必須とする
- PR description に「snapshot 変更理由」を 1 行で書く（例: 「HomeScreen 余白調整に伴う再記録」）
- 不要な再記録（実装変更を伴わないデバイス文字列の更新等）は別 commit に分けて理由を明示

### 5. Flaky 対策

snapshot が flaky になった場合の優先順位:

1. **環境固定の見直し**: simulator OS バージョン、フォント、Dynamic Type
2. **タイミング**: async load との race を疑う → state-driven な内部 view を抽出（Phase 1 で HomeContentView を抽出した実例）
3. **picture exclusion**: 一部領域を mask（`assertSnapshot(... as: .image(precision: 0.99))` で許容差を設定）
4. **最後の手段**: その snapshot をスキップ（`@Test(.disabled("flaky"))`）して issue 化

flaky 対応の決定は test-engineer エージェントが提案、HITL で確定。

### 6. 雑然防止

- `__Snapshots__/Failures/` は `.gitignore` する（既に xcuserdata 等で吸収されているか確認）
- snapshot file 名は `<test-method>.<index>.png` の library default に従う（カスタム命名はしない）
- 1 つの test で複数の snapshot を撮るのは原則禁止（test の意図を分割）

## Consequences

### Positive

- Phase 2 で snapshot が一気に増えても、運用が標準化されるので混乱しない
- record cycle が明示されているので新規実装者（subagent / 人）が迷わない
- flaky 対応の意思決定パスが明示されている

### Negative

- iPhone X config 固定は将来 device バリエーションを増やしたいときに ADR 更新が要る
- ダークモード固定で light/dark コントラスト regression に気付きにくい（コンセプト合致しているので allowable）

### Neutral

- swift-snapshot-testing API は流動的。library 1.20+ で record の指定方法が変わる可能性 → 都度 retro で確認

## Alternatives Considered

### iPhone 16 / 17 などの新モデル `ViewImageConfig` を自前定義

- ✅ 最新デバイスで snapshot が取れる
- ❌ swift-snapshot-testing 上流に PR を出すべき内容で、ローカル定義は drift リスク
- 採用条件: 上流が長期間追従しない場合のみ、ADR で正式化して定義

### Snapshot を CI 専用ジョブに分離

- ✅ ローカル `make verify` が軽くなる
- ❌ Phase 2 まで CI 自体を整備していない（Phase 0 で .github/workflows/ci.yml は削除済）
- 将来検討: CI 整備時に snapshot ジョブ分離を再評価

### Pixel-perfect 比較を緩めて差分許容（`precision: 0.95` など）

- ✅ flaky 削減
- ❌ 本物の regression を見逃すリスク
- 採用条件: flaky 個別ケースで個別判断

## References

- [ADR 0001 — iOS Native Technology Stack](0001-stack-decision.md)
- [Phase 1 retro](../harness/phase1-retro.md)
- [HomeScreen snapshot tests](../../packages/AwaIroPresentation/Tests/AwaIroPresentationTests/HomeScreenSnapshotTests.swift)
- [swift-snapshot-testing](https://github.com/pointfreeco/swift-snapshot-testing)
