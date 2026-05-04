# Autonomy Gate Matrix — HITL / HOTL / HOOTL

> 「不可逆性 × 影響範囲 × 決定論性」で操作を 3 層に分類し、エージェントが「迷わず動ける」ようにするためのルール表。詳細な根拠は [ADR 0002](../adr/0002-multi-agent-harness.md)、概念は [Spec](../superpowers/specs/2026-05-04-kmp-to-ios-conversion-design.md) 参照。

## Tiers

| 区分 | 意味 | 既定挙動 |
|------|------|---------|
| 🔴 **HITL** (Human In The Loop) | 都度承認 | エージェントは操作前に必ず人に確認する |
| 🟡 **HOTL** (Human On The Loop) | 自動進行・差分通知 | エージェントは進行するが差分を通知。人は監督・介入可能 |
| 🟢 **HOOTL** (Human Out Of The Loop) | 完全自律・通知なし | エージェントは黙って実行 |

## Operation Classification

### 🔴 HITL — 都度承認が必要

| 操作 | 理由 | 自動 block |
|------|------|----------|
| `git push` / PR 作成 / PR merge | 共有状態への公開、不可逆寄り | ✅ hitl-bash-gate.sh |
| `git branch -D` / 強制 branch 削除 | 不可逆 | ✅ hitl-bash-gate.sh |
| `git rm -r` (mass) / `rm -rf` | 巻き戻しコスト大 | ✅ hitl-bash-gate.sh |
| `git reset --hard` | 未 commit 作業破棄 | ✅ hitl-bash-gate.sh |
| `git merge` | 履歴に影響 | ✅ hitl-bash-gate.sh |
| `brew/npm/pip install` | サプライチェーン | ✅ hitl-bash-gate.sh |
| Xcode project / workspace 内部編集 | ビルド全体への波及 | ✅ hitl-edit-gate.sh |
| `Info.plist` 編集 | 権限・capabilities | ✅ hitl-edit-gate.sh |
| `*.entitlements` 編集 | サンドボックス境界 | ✅ hitl-edit-gate.sh |
| `Package.swift` 編集 | 依存・ターゲット定義 | ✅ hitl-edit-gate.sh |
| `Package.resolved` 編集 | pinned dep 改ざん | ✅ hitl-edit-gate.sh |
| DB スキーマ変更 / マイグレーション | データ破壊リスク | ⚠️ 規約のみ（自動 block 不可）|
| ADR 確定 / Concept Guardrail 変更 | 設計憲法レベル | ⚠️ 規約のみ |

#### HITL bypass — ユーザー承認済み操作の素通し

人がチャットで明示的に承認した HITL 操作は、Bash コマンドの先頭に `HITL_BYPASS=1` を付けて実行すれば `hitl-bash-gate.sh` を素通りできる:

```bash
HITL_BYPASS=1 git push origin main
HITL_BYPASS=1 brew install swift-format
```

**使うタイミング:** ユーザーが「OK」「承認」等の明示同意を返した直後、その操作1回限り。bypass の使用は記録目的なので、**ユーザー承認なしに自分で付けるのは規約違反**。Reviewer エージェントは PR 内に `HITL_BYPASS=1` の使用がある場合、対応するチャット承認の経緯を確認する。

`hitl-edit-gate.sh`（sensitive file 編集）には現時点で bypass 機構なし。Edit/Write はユーザーが diff を見れる状況で起きるため、必要なら手動で hook を一時無効化（settings.json から削除）して再有効化する運用。

### 🟡 HOTL — 自動進行・差分通知

| 操作 | 理由 |
|------|------|
| ファイル新規/編集（Domain / Data / Presentation 配下）| 局所・可逆 |
| テスト作成・実行 / Snapshot 記録 | 局所 |
| ローカルビルド（simulator）| 局所 |
| Conventional Commit（push 前）| ローカル commit は reset で巻き戻せる |
| Reviewer の通常指摘 | ループの一部 |

### 🟢 HOOTL — 完全自律・通知なし

| 操作 | 理由 |
|------|------|
| Read 系（Read / Glob / Grep）| 副作用なし |
| `swift-format` / `swift-format --fix`（hook 内） | 決定論的・可逆 |
| SPM resolve（既存依存の解決）| 決定論的 |
| Snapshot 差分の表示（記録は HOTL）| 副作用なし |

#### HOOTL 適格基準（全て満たすこと）

1. **完全に決定論的** — 同入力なら同出力
2. **ファイル変更が局所的かつ自動可逆** — 再実行で正規化できる
3. **外部状態に影響しない** — push / API 呼び出し / 通知 / 共有リソース変更なし
4. **失敗が即検知できる** — `make verify` で必ず引っかかる、または操作自体が no-op

1 つでも崩れたら HOTL 以上に分類する。

## Auto-escalation / Auto-demotion Triggers

### 自動 HITL 昇格（HOTL → HITL）

HOTL モード中に以下が発火したら停止して人を呼ぶ:

- ローカルビルドが連続2回失敗
- Reviewer が `blocker` 相当の重大指摘
- Concept Guardrail テストが赤
- スキーマ／ビルド設定／entitlements ファイルへの差分検出
- セキュリティ系の発見（鍵らしき文字列、ハードコードされた秘密、危険な権限要求）
- スコープ外の変更（plan に無いファイルへの編集）

### 自動 HOTL 降格（HOOTL → HOTL）

HOOTL 操作で以下が発火したら、その操作を HOTL に降格して人に通知:

- HOOTL 操作が予期せぬ振る舞いを示した（例: swift-format がコード意味を変えた、または diff が想定より大きい）
- HOOTL hook で複数ファイルにまたがる不整合を検出
- セキュリティスキャン（HOOTL の Read 系の一種）で秘密情報を検出
- HOOTL 操作の連続失敗

## Trust Ladder — 自律度の昇降格パス

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

判断は各 Phase 末の retro で実施:

- **Phase 0 末**: Phase 1 走行に向けて昇降格を判定
- **Phase 1 末**: 残り 3 役の追加と同時に gate 表を改訂
- **Phase 2 / 3 末**: 累積知見で再評価

### 昇降格の例（参考）

- Reviewer の trivial diff（typo 修正、import 順正規化）への approve → 安定後に HOTL → HOOTL
- 新規 SPM 依存追加 → 初期は HITL、信頼ある依存元（Apple, point-free 等）の routine update は HOTL に降格可能
- swift-format の挙動が一度でもコード意味を変えたら → HOOTL → HOTL に昇格

## Change history

| Date | Change | Reason |
|------|--------|--------|
| 2026-05-04 | 初版作成 | Phase 0 Bootstrap 時に [Spec](../superpowers/specs/2026-05-04-kmp-to-ios-conversion-design.md) から抽出 |
