# AwaIro — Concept Guardrails

> 「制約が豊かさを生む」というコンセプトを、コードに落とし込んで守るための不変条件リスト。各 guardrail は対応するテストとセットで管理し、Code Reviewer エージェントが照合する。

## Why this exists

AwaIro の価値は機能ではなく**制約**にある。1日1枚、翌日まで非表示、数字なし、通知で促さない。これらは UI の見た目の問題ではなく、**ドメインルール**として使われ方を強制する必要がある。

仕様書だけだと劣化する。テストに落とすことで、「コンセプトが壊れたら CI が赤くなる」状態を作る。

## Guardrails

### G1. 1日1枚

> ユーザーは 1 日（端末ローカル時刻）に 1 枚しか写真を保存できない。同日に再撮影しようとした場合は、UseCase レベルで拒否する。

| 項目 | 内容 |
|------|------|
| Phase | Phase 2 で実装 |
| 実装場所 | `AwaIroDomain.RecordPhotoUseCase` |
| エラー | `RecordPhotoError.alreadyRecordedToday` |
| テスト | `RecordPhotoUseCaseTests.testSecondPhotoSameDayReturnsAlreadyRecorded` |
| 検証データ | 同日内の異なる時刻、日付境界（23:59 と 00:00）、タイムゾーン跨ぎ |

### G2. 翌日まで非表示（現像）

> 撮影直後の写真は、最短翌日（撮影時刻 + 24h 以降）まで「現像済」状態にならない。それ以前にアクセスしようとしても表示しない。

| 項目 | 内容 |
|------|------|
| Phase | Phase 3 で実装 |
| 実装場所 | `AwaIroDomain.DevelopUseCase.canDevelop(takenAt:now:)` |
| 戻り値 | `Bool` — `now < takenAt + 24h` で false |
| テスト | `DevelopUseCaseTests.testCanDevelopFalseWithin24h` |
| 検証データ | 撮影直後、23h59m 後、24h ちょうど、24h+1s 後 |

### G3. 数字なし

> View ツリー内に「いいね数」「フォロワー数」「閲覧数」などの数値表示が**存在しない**。Snapshot テストで文字列出現を検査する。

| 項目 | 内容 |
|------|------|
| Phase | Phase 1 から（Walking Skeleton で最初の guardrail として導入）|
| 実装場所 | `HomeScreen` 等の SwiftUI View ツリー |
| テスト | `HomeScreenSnapshotTests.testNoNumericMetricsDisplayed` |
| 検査方法 | View をレンダリングして文字列抽出 → 禁止語リスト（`いいね`, `Like`, `フォロワー`, `Follower`, `閲覧`, `Views`, etc.）に該当しないことを assert |
| 注意 | 撮影日付や設定画面の数値（例: 通知件数）は対象外。「他者からの評価指標」を禁止する |

### G4. アクティブ通知で訪問を促さない

> Push 通知の権限要求や entitlements を Info.plist に持たない。「現像できるよ」という通知はしない。

| 項目 | 内容 |
|------|------|
| Phase | Phase 1 から |
| 実装場所 | `App/Info.plist`, App Target の Capabilities |
| テスト | `InfoPlistGuardrailTests.testNoPushNotificationCapability` |
| 検査方法 | Info.plist をパースし、`UIBackgroundModes` に `remote-notification` が無いこと、`aps-environment` entitlement が存在しないことを assert |

### G5. 個人特定不能な位置情報のみ記録（Sprint 3 想定）

> 緯度経度ではなく、行政区レベル（区・市町村）のみを保存する。Reverse geocode 結果の `subAdministrativeArea` または `locality` のみ採用。

| 項目 | 内容 |
|------|------|
| Phase | Sprint 3 想定（このプロジェクトではまだ実装しない）|
| 実装場所 | `AwaIroPlatform.LocationService` |
| テスト | `LocationServiceTests.testNeverStoresExactCoordinates` |
| 検査方法 | LocationService の戻り値型に `latitude/longitude` プロパティが**存在しない**ことを型レベルで保証 |

## How Reviewers use this

Code Reviewer エージェントは PR の差分を見て、上記 guardrail に該当する変更がある場合、対応するテストが緑であることを `make verify` で確認する。テストが無い場合は HITL に昇格させて Architect の判断を仰ぐ。

新規 guardrail を追加する場合は、このドキュメントに追記 → 対応テストを書く → ADR で根拠を残す（G6 以降）の順で進める。

## References

- Concept: [AwaIro_Concept.md](../AwaIro_Concept.md)
- Spec: [2026-05-04-kmp-to-ios-conversion-design.md](superpowers/specs/2026-05-04-kmp-to-ios-conversion-design.md)
