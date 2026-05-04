# ADR 0003 — SPM Module Boundaries and Dependency Direction

- Status: Accepted
- Date: 2026-05-04
- Deciders: nusnody, Orchestrator (Claude Opus 4.7)

## Context

iOS ネイティブ実装で Clean Architecture を採用するにあたり、層の境界を「ドキュメント上の約束」ではなく「物理的な依存制約」で強制したい。Swift Package Manager のパッケージ境界は import 違反を compile-time に検出できる。

## Decision

4 SPM パッケージを `packages/` 配下に配置し、依存方向を厳守する。

```
App (Xcode App Target)
 └─ AwaIroPresentation
      ├─ AwaIroDomain
      └─ AwaIroPlatform
           └─ AwaIroDomain
AwaIroData
 └─ AwaIroDomain
```

### 各パッケージの責務

| パッケージ | 責務 | 制約 |
|-----------|------|------|
| AwaIroDomain | 値型 model / Repository protocol / UseCase | **Pure Swift。UIKit / SwiftUI / Foundation 以外の iOS フレームワーク import 禁止** |
| AwaIroData | GRDB / migration / Repository 実装 / Mapper | Foundation + GRDB のみ。UIKit/SwiftUI 禁止 |
| AwaIroPlatform | Camera (AVFoundation) / Metal / FileManager / Share | iOS フレームワーク依存可。Domain protocol を実装 |
| AwaIroPresentation | SwiftUI Views / @Observable VM / Navigation | SwiftUI 必須。Data に直接依存禁止（Domain 経由）|

### App Target の役割

- @main, App ライフサイクル
- AppContainer（Composition Root：手書き DI）
- ナビゲーション root（NavigationStack）
- 全 SPM パッケージを束ねる

## Consequences

### Positive

- Domain が UI フレームワークから物理的に隔離される（import できない）
- Android 復活時はパッケージ単位で Kotlin 化（Domain → KMP common, Data → JVM/Android, Platform → Android, Presentation → Compose）
- パッケージごとに独立したテストターゲットがあり、並列実行可能
- 違反は compile error なので CI で必ず捕捉

### Negative

- 初期セットアップが単一ターゲットより複雑
- パッケージ追加時は Package.swift を手動編集
- Xcode の indexing がパッケージ数に応じて遅くなる可能性

### Neutral

- App Target は Phase 1 で再生成する（Phase 0 では SPM パッケージのみ）

## Alternatives Considered

### 単一 Xcode App Target + フォルダ分け

- ❌ レイヤ違反が compile-time に検出できない（規約遵守は人の目に依存）
- ❌ Android 復活時にパッケージ抽出が必要になり、結局この作業が後ろ倒しになるだけ

### 5+ パッケージ細分化（UseCase ごとに分割など）

- ❌ オーバーキル。MVP 規模では 4 で十分
- 将来肥大化したら新規 ADR で再分割を検討

### Tuist / XcodeGen による project 生成

- ✅ Xcode project の手動管理を避けられる
- ❌ サードパーティツール導入が必要（spec の方針に反する）
- 将来検討: パッケージ数が 10+ になったら再評価

## References

- Spec: [2026-05-04-kmp-to-ios-conversion-design.md](../superpowers/specs/2026-05-04-kmp-to-ios-conversion-design.md)
- Phase 0 plan: [2026-05-04-phase-0-bootstrap.md](../superpowers/plans/2026-05-04-phase-0-bootstrap.md)
