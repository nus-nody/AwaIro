# ADR 0002 — Multi-Agent Development Harness

- Status: Accepted
- Date: 2026-05-04
- Deciders: nusnody, Orchestrator (Claude Opus 4.7)

## Context

KMP→iOS コンバートを含む大規模な変更を、複数の専門領域に渡って効率よく進める必要がある。単一エージェントが全領域を担うと、コンテキスト切り替えコストが高く、判断品質も平均化される。

## Decision

5+1 専門エージェントが協調する。各役割は `.claude/agents/<name>.md` で定義し、Orchestrator（主担当）が `Agent` ツールで `subagent_type` を指定して dispatch する。

| # | 役割 | モデル | 既定モード |
|---|------|--------|----------|
| 1 | iOS Architect（Product 兼務）| Opus 4.7 | HITL |
| 2 | iOS Engineer | Sonnet 4.6 | HOTL |
| 3 | Test Engineer | Sonnet 4.6 | HOTL |
| 4 | Code Reviewer | Opus 4.7 | HOTL（重大時 HITL）|
| 5 | Build/DevOps Engineer | Sonnet 4.6（設計）/ Haiku 4.5（定常）| HOTL |
| 6 | UX Designer (Light) | Sonnet 4.6 | HITL |
| — | Orchestrator | Opus 4.7 (1M) | — |

自律度は 3 層モデル（HITL / HOTL / HOOTL）でゲート判定し、Trust Ladder で Phase 末 retro 時に昇降格する。詳細は [docs/harness/gate-matrix.md](../harness/gate-matrix.md) 参照。

## Consequences

### Positive

- 役割固有のシステムプロンプトで判断品質が上がる
- モデル選択（Opus/Sonnet/Haiku）でコスト最適化
- HITL/HOTL/HOOTL の明示で「迷ったら止まる」「決定論的処理は自走」が機械的に決まる
- Phase 1 末 retro で役割の削減/統合が可能（YAGNI 適用）

### Negative

- 役割が増えるとコンテキスト切替オーバーヘッドが発生（dispatch 単位で fresh context）
- 役割定義の保守が必要（変更時は ADR 追加）

### Neutral

- Phase 0 では Architect / Engineer / Reviewer の 3 役を作成。残り 3 役（test-engineer / devops / ux-designer）は当初 Phase 1 末で追加予定だったが、Phase 0 末 retro（2026-05-04）の判断により Phase 1 開始前に前倒しで追加。Phase 1 plan の Tasks 5/9（test-engineer）・11-12/15（devops）・8（ux-designer）で実戦投入する

## Alternatives Considered

### Lean (3 役: Architect / Engineer / Reviewer のみ)

- ❌ Test と DevOps が Engineer と混ざり、責任所在が曖昧化
- ❌ UX 観点が抜けると視覚品質の責任者が不在

### Full (6 役 + Product Steward 独立)

- ❌ Product Steward の出番が低頻度で形骸化リスク高
- 採用案では Architect が Product を兼務

### 単一エージェント

- ❌ コンテキスト肥大化で判断品質低下
- ❌ 専門性のメリットが消える

## References

- Spec: [2026-05-04-kmp-to-ios-conversion-design.md](../superpowers/specs/2026-05-04-kmp-to-ios-conversion-design.md)
- Gate Matrix: [docs/harness/gate-matrix.md](../harness/gate-matrix.md)
