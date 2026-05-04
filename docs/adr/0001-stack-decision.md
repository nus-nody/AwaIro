# ADR 0001 — iOS Native Technology Stack

- Status: Accepted
- Date: 2026-05-04
- Deciders: nusnody, Orchestrator (Claude Opus 4.7)

## Context

AwaIro はこれまで Kotlin Multiplatform + Compose Multiplatform で構築されてきた。テスト容易性とイテレーション速度に課題があり、iOS 専用ネイティブ実装に転換する。同時に Android 復活の可能性は残すため、Domain/Data 層は iOS フレームワーク非依存に保つ必要がある。

## Decision

以下のスタックを採用する:

| レイヤ | 採用 |
|--------|------|
| UI | SwiftUI（カメラプレビューのみ `UIViewRepresentable` で AVCaptureVideoPreviewLayer 経由）|
| 状態管理 | `@Observable`（Swift 5.9+）|
| 並行処理 | Swift Concurrency（async/await + actor）|
| アーキテクチャ | Clean Arch 3層（Presentation / Domain / Data）|
| DI | Init Injection + 手書き `AppContainer`（サードパーティ DI なし）|
| 永続化 | GRDB.swift（SQL ベース）|
| テスト | Swift Testing（新規）+ swift-snapshot-testing（SwiftUI）|
| 画像 | 標準 `AsyncImage` + `ImageRenderer` |

## Consequences

### Positive

- Domain 層が Pure Swift になり、単体テストが軽量・高速
- @Observable は Combine 不要で SwiftUI と自然に統合
- GRDB は SQLDelight と SQL 思考が共通 → Android 復活時に Room へ移行しやすい
- Swift Testing は XCTest より宣言的で読みやすい
- サードパーティ DI なし → 学習コスト低、依存削減

### Negative

- @Observable は iOS 17+ 限定（最低サポートを iOS 17 に固定）
- Swift Testing は Xcode 16+ 必須(現環境 Xcode 26.4.1 で OK)
- GRDB は SQL を書く必要がある（ORM の自動化は無い）→ migration を慎重に管理する必要

### Neutral

- swift-snapshot-testing は外部依存になるが、SwiftUI の視覚回帰検出に唯一実用的な選択肢

## Alternatives Considered

### UI: UIKit

- ❌ Snapshot テストは可能だが、宣言的 UI の生産性で SwiftUI に劣る
- ❌ Camera プレビュー以外で UIKit を選ぶ理由がない

### 状態管理: TCA (The Composable Architecture)

- ✅ テスト容易性は高い
- ❌ 学習コスト高く、@Observable で十分なケースで過剰
- ❌ Reducer/Action のボイラープレートが多い
- 将来検討: 状態が複雑化したら採用を再検討（新規 ADR で）

### 永続化: SwiftData

- ✅ Apple 純正、@Model マクロで宣言的
- ❌ iOS 17+ 限定で macOS 14+ にも制約
- ❌ 概念が iOS 専用すぎて Android 復活時に Room へ移行困難
- ❌ migration が現状不安定（実プロジェクトで報告多数）

### 永続化: Core Data

- ✅ 成熟した技術、移行ツール豊富
- ❌ NSManagedObject の手続き型 API が情緒に合わない
- ❌ Android 移植時に概念マッピングが SwiftData と同程度に困難

### テスト: XCTest 一本

- ✅ ドキュメント・実例が豊富
- ❌ Swift Testing の宣言的 `@Suite` / `@Test` の方が読みやすく、新規プロジェクトで採用するのが定石

## References

- Spec: [2026-05-04-kmp-to-ios-conversion-design.md](../superpowers/specs/2026-05-04-kmp-to-ios-conversion-design.md)
