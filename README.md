# AwaIro

1日1枚だけ、翌日まで見られない。感情の痕跡を溜めるフォトウォークアプリ（iOS ネイティブ）。

## 開発セットアップ

### 必要なツール

- Xcode 26 以上（Swift 6, Swift Testing 同梱）
- macOS 14 (Sonoma) 以上
- (任意) `swift-format` — `brew install swift-format`

詳細は [docs/manual/00-prerequisites.md](docs/manual/00-prerequisites.md) を参照。

### ビルド & テスト

```bash
make verify     # build + test + lint（Definition of Done）
make build      # SPM パッケージのみビルド
make test       # SPM パッケージのテスト全実行
make help       # 全ターゲット一覧
```

Phase 0 では SPM パッケージ単位の検証のみ。iOS App ターゲットは Phase 1 で再生成する。

## アーキテクチャ

Clean Architecture 3 層（Presentation / Domain / Data）。SPM 4 パッケージで物理的に層境界を強制。

```
App                                # Xcode App Target（Phase 1 で生成）
└─ AwaIroPresentation              # SwiftUI Views + @Observable VMs
     ├─ AwaIroDomain               # Pure Swift（model / protocol / usecase）
     └─ AwaIroPlatform             # AVFoundation, Metal, FileManager
          └─ AwaIroDomain
AwaIroData                         # GRDB, repository 実装
└─ AwaIroDomain
```

詳細は [ADR 0003](docs/adr/0003-spm-module-boundaries.md)。

## ドキュメント

- [Concept](AwaIro_Concept.md) — なぜ作るのか、何を大事にしているか
- [Concept Guardrails](docs/concept-guardrails.md) — コンセプトを守るための不変条件
- [ADR Index](docs/adr/README.md) — 技術決定の履歴
- [Conversion Spec](docs/superpowers/specs/2026-05-04-kmp-to-ios-conversion-design.md) — KMP→iOS 移行設計
- [Gate Matrix](docs/harness/gate-matrix.md) — HITL/HOTL/HOOTL ゲート

## 開発ハーネス

5+1 専門エージェントが協調する。詳細は [ADR 0002](docs/adr/0002-multi-agent-harness.md)。

| 役割 | モデル | 既定モード |
|------|--------|----------|
| iOS Architect | Opus 4.7 | HITL |
| iOS Engineer | Sonnet 4.6 | HOTL |
| Test Engineer | Sonnet 4.6 | HOTL |
| Code Reviewer | Opus 4.7 | HOTL |
| Build/DevOps Engineer | Sonnet 4.6 / Haiku 4.5 | HOTL |
| UX Designer Light | Sonnet 4.6 | HITL |

## スプリント

| Sprint / Phase | 機能 | 状態 |
|---------------|------|------|
| Conversion Phase 0 | Bootstrap | ✅ 完了 |
| Conversion Phase 1 | Walking Skeleton | ✅ 完了 |
| Conversion Phase 2 | Sprint 1 (記録) port | 🔨 次フェーズ |
| Conversion Phase 3 | Sprint 2 (現像) ネイティブ実装 | 📋 計画予定 |
| 旧 Sprint 0/1 | KMP 基盤・記録機能 | 📦 archive/kmp ブランチに保管 |

## KMP コードについて

旧 KMP 実装は `archive/kmp` ブランチに完全保存されている（タグ: `archive/kmp-v1.0.0`）。Android 復活時の参照点として使用する。

```bash
git fetch origin archive/kmp
git checkout origin/archive/kmp -- composeApp/    # 部分的に復活させたい場合
```
