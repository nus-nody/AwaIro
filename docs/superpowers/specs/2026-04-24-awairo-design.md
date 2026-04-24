# AwaIro — アーキテクチャ設計書

**作成日:** 2026-04-24  
**対象:** Sprint 0〜3 全体設計  
**ステータス:** 承認済み

---

## 1. プロジェクト概要

AwaIroは「1日1枚・翌日まで見られない・数字なし」の制約で感情の痕跡を溜めるフォトウォーク体験アプリ。

- **動作環境:** iOS / Android（Compose Multiplatform）
- **初期スコープ:** ローカル完結（サーバーなし）
- **将来拡張:** バックエンド追加時はDataレイヤーのみ差替

---

## 2. 技術スタック

| 役割 | 採用技術 | バージョン方針 |
|------|----------|----------------|
| UI + 共通ロジック | Compose Multiplatform (KMP) | 最新安定版 |
| ローカルDB | SQLDelight | KMP対応、スキーマ管理あり |
| 依存注入 | Koin | KMP対応、シンプルなDSL |
| 状態管理 | ViewModel + StateFlow | Compose公式パターン |
| 日時処理 | kotlinx-datetime | KMP対応（java.timeはKMPで使えない） |
| 画像EXIF処理 | androidx.exifinterface (Android) / ImageIO (iOS) | expect/actualで抽象化 |
| CI/CD | GitHub Actions | PRごとにビルド確認。GitHub連携はMCP経由 |
| 依存関係管理 | Gradle Version Catalog (libs.versions.toml) | 一元管理 |

### OSサポート方針

- **Android:** API Level 34以上（Android 14+）。最新メジャーバージョンに追従
- **iOS:** iOS 17以上。最新メジャーバージョンに追従
- 古いOSは切り捨てて、最新APIを活用する方針

---

## 3. アーキテクチャ — Clean Architecture 3層構造

```
Presentation層（画面・ViewModel）
        ↓ 呼び出す
Domain層（UseCase・Modelインターフェース）
        ↓ 実装を注入
Data層（Repository実装・SQLDelight）
```

- **Presentation → Domain:** ViewModelがUseCaseを呼ぶ。UIはDomainに依存しない
- **Domain → Data:** DomainはRepositoryインターフェースのみ知る。実装は知らない
- **Data → Domain:** RepositoryがSQLDelightと話す。Domainモデルに変換して返す

将来サーバーを追加する場合、Data層のRepository実装を差し替えるだけで上位レイヤーは無変更。

---

## 4. ディレクトリ構成

```
AwaIro/
├── composeApp/
│   ├── src/
│   │   ├── commonMain/kotlin/io/awairo/
│   │   │   ├── domain/
│   │   │   │   ├── model/
│   │   │   │   │   └── Photo.kt          # id, capturedAt, imageBytes, memo, location
│   │   │   │   ├── repository/
│   │   │   │   │   └── PhotoRepository.kt # インターフェース
│   │   │   │   └── usecase/
│   │   │   │       ├── RecordPhotoUseCase.kt    # Sprint1
│   │   │   │       ├── DevelopPhotoUseCase.kt   # Sprint2
│   │   │   │       └── GenerateCardUseCase.kt   # Sprint3
│   │   │   ├── data/
│   │   │   │   ├── local/
│   │   │   │   │   └── AwaIroDatabase.sq  # SQLDelightスキーマ
│   │   │   │   └── repository/
│   │   │   │       └── LocalPhotoRepository.kt  # 実装
│   │   │   └── presentation/
│   │   │       ├── screen/
│   │   │       │   ├── CaptureScreen.kt   # Sprint1: 撮影画面
│   │   │       │   ├── GalleryScreen.kt   # Sprint2: 現像後ギャラリー
│   │   │       │   └── CardScreen.kt      # Sprint3: フォトカード
│   │   │       └── viewmodel/
│   │   │           ├── CaptureViewModel.kt
│   │   │           ├── GalleryViewModel.kt
│   │   │           └── CardViewModel.kt
│   │   ├── androidMain/kotlin/io/awairo/
│   │   │   └── MainActivity.kt
│   │   └── iosMain/kotlin/io/awairo/
│   │       └── MainViewController.kt
├── iosApp/                          # iOS Xcodeエントリポイント
├── docs/
│   ├── superpowers/specs/           # 設計書（本ファイル）
│   └── manual/                      # 手動操作が必要な手順書
├── .github/
│   └── workflows/
│       └── ci.yml                   # GitHub Actions CI定義
└── gradle/
    └── libs.versions.toml           # 依存関係一元管理
```

---

## 5. Domainモデル

### Photo（核となるエンティティ）

```
Photo
  id: String (UUID)
  capturedAt: Long (epoch ms)
  developedAt: Long (capturedAt + 24h)
  imagePath: String (アプリサンドボックス内のファイルパス。バイナリはDBに入れない)
  memo: String (最大100文字)
  areaLabel: String (区・エリア名。緯度経度は保存しない)
  isDeveloped: Boolean (computed: now >= developedAt)
```

### 制約ルール（UseCaseで強制）

- 「1日」はデバイスのローカル日付（yyyy-MM-dd、kotlinx-datetime基準）
- 同一ローカル日付に既存Photoがあれば `RecordPhotoUseCase` はエラーを返す（1日1枚）
- `isDeveloped = false` のPhotoの `imagePath` はUIに渡さない（現像前保護）
- 画像ファイルはアプリのサンドボックス内（Documents/photos/）に保存し、DBにはパスのみ持つ
- **画像保存時にEXIF（GPS・機種情報）を除去**してから保存
- 画像フォルダはOS backup対象外フラグを設定（iOS: NSURLIsExcludedFromBackupKey / Android: android:allowBackup="false" or BackupAgent）

---

## 6. スプリント計画

### リリース可能性の共通要件（全Sprint共通）

各スプリント終了時に以下を満たすこと：

- [ ] Android: `./gradlew assembleRelease` でAPK/AABが生成できる
- [ ] iOS: Xcodeで Release ビルドがシミュレータで動作する
- [ ] その時点の機能だけでユーザー体験が完結している（中途半端な画面を残さない）
- [ ] CIがgreen
- [ ] 実機（または少なくともシミュレータ）で動作確認済み

### Sprint 0 — 基盤構築（今回のゴール）

**完了条件:**
- [ ] Compose Multiplatformプロジェクトが作成されている
- [ ] Android / iOS 両方でHello World画面がビルド・起動できる
- [ ] SQLDelightのスキーマが定義されDBが初期化できる
- [ ] KoinのDIコンテナが設定されている
- [ ] kotlinx-datetimeが組み込まれている
- [ ] `FirstLaunchGate`インターフェースが空実装で存在する（チュートリアル後付け用の差し込み口）
- [ ] `ShareService`インターフェースが定義されている（expect/actual、Sprint 3で実装）
- [ ] バックアップ除外の設定がiOS/Androidで入っている
- [ ] GitHub Actionsが設定され、pushでビルドが走る（GitHub連携はMCP経由）
- [ ] `docs/manual/` に手動手順書がある

### Sprint 1 — 記録する

**追加コンポーネント:** `RecordPhotoUseCase` + `CaptureScreen` + `CaptureViewModel`

**体験できること:**
- カメラで1枚撮影（または写真ライブラリから選択）
- 一言メモを添える
- 1日1枚制限（2枚目を撮ろうとするとブロック）

**完了条件:**
- [ ] 撮影→保存フローが動く
- [ ] 同日2枚目撮影でエラーメッセージが表示される
- [ ] 保存したPhotoがDBに存在することをログで確認できる

### Sprint 2 — 現像する

**追加コンポーネント:** `DevelopPhotoUseCase` + `GalleryScreen` + `GalleryViewModel`

**体験できること:**
- 撮影から24時間後に写真が「現像」される
- 現像済みの写真だけギャラリーに表示される
- 現像前はサムネイルが表示されない（フィルムカメラ的体験）

**完了条件:**
- [ ] 現像前の写真はブラー/プレースホルダーで表示
- [ ] 24時間経過後に自動で閲覧可能になる
- [ ] ギャラリーが時系列で並ぶ

### Sprint 3 — 渡す

**追加コンポーネント:** `GenerateCardUseCase` + `CardScreen` + `CardViewModel` + `ShareService`の実装

**体験できること:**
- 現像済みの写真から1枚のフォトカードを生成
- 端末標準のシェア機能で配布：
  - iOS: AirDrop / メッセージ / LINE / カメラロール保存
  - Android: Intent.ACTION_SEND経由でLINE / Gmail / ギャラリー保存
- 通信機能は**持たない**。あくまで端末のシェアシート経由

**完了条件:**
- [ ] フォトカードのレイアウトが表示される
- [ ] 画像として一時ファイルに書き出される
- [ ] iOS/Android両方でシステム標準のシェアシートが開く
- [ ] 書き出し画像のEXIFは除去されている
- [ ] カメラロール／ギャラリーへの保存ができる

---

## 7. CI/CD設計

```yaml
# .github/workflows/ci.yml のイメージ
トリガー: push / pull_request (mainブランチ)
ジョブ:
  - build-android: ./gradlew assembleDebug
  - build-ios: xcodebuild (macOS runner)
```

- PRごとにビルドが通ることを自動確認
- テストは後続スプリントで追加（Sprint 0ではビルド確認のみ）

---

## 8. 手動操作が必要な項目

詳細は `docs/manual/` 配下に個別ドキュメントを置く。

| # | 操作 | タイミング | 詳細ファイル |
|---|------|-----------|--------------|
| 0 | 事前インストール一覧 | Sprint 0着手前 | `manual/00-prerequisites.md` |
| 1 | Android Studio + KMP plugin | Sprint 0着手前 | `manual/00-prerequisites.md` |
| 2 | Xcode インストール | Sprint 0着手前 | `manual/00-prerequisites.md` |
| 3 | JDK 17 + Node.js + gh CLI | Sprint 0着手前 | `manual/00-prerequisites.md` |
| 4 | GitHub Actionsのシークレット設定 | CI設定時 | 後続で追加 |
| 5 | Apple Developer登録（実機テスト時） | Sprint 3終盤 | 後続で追加 |

**GitHub連携について:** 現時点でGitHub MCP専用ツールは組み込まれていないため、`gh` CLIをBash経由で使用します。

---

## 9. セキュリティ方針

- 写真データはアプリのサンドボックス内にのみ保存。**通信機能は持たない**
- 位置情報は区・エリア名のみ保存（緯度経度は即時破棄）
- 保存時・書き出し時に**EXIFデータを必ず除去**（GPS・機種・撮影時刻メタデータの流出防止）
- 写真フォルダは**OSバックアップ対象外**（iCloud / Google Auto Backup に乗らない）
- シェアは**端末標準のシェアシート**のみ（アプリ自身が通信しない）
- カメラ・フォトライブラリ権限は用途説明を明記してリクエスト
- 依存ライブラリはGradle Version Catalogで一元管理し、バージョン固定
- 将来バックエンド追加時は通信はHTTPS必須、認証はOAuth 2.0

## 10. 拡張点（将来の後付け用）

各拡張点はSprint 0で空実装のインターフェースだけ用意し、後から差し替え可能にする。

| 拡張点 | インターフェース | 用途 |
|--------|------------------|------|
| チュートリアル | `FirstLaunchGate` | 初回起動時に何を表示するか差し込める |
| クラッシュレポート | `CrashReporter` | 将来Sentry等を追加 |
| 分析 | `EventTracker` | 将来匿名分析を追加（現状は空実装） |
| バックエンド同期 | `SyncService` | 将来クラウド同期を追加 |

## 11. コスト見積もり（年間）

| 項目 | 費用 | 必須タイミング |
|------|------|----------------|
| GitHub Actions（publicリポ） | $0 | Sprint 0〜 |
| GitHub Actions（privateリポ・macOS runner使用） | 〜$10/月 | privateで運用する場合 |
| Apple Developer Program | $99/年 | 実機配布 / App Store配信時 |
| Google Play Developer | $25（買い切り） | Play Store配信時 |
| バックエンド | $0 | ローカル完結のため不要 |
| **MVP最小構成** | **$0** | シミュレータのみ運用 |
| **実機配布構成** | **$99** | Apple Developer必要 |

---

## 12. 未決定事項（後続スプリントで決める）

- エリア名の取得方法（オフラインGeocoding or 手入力）
- フォトカードのデザインテンプレート数と様式
- 現像の通知方法（ローカル通知 or バッジのみ）
- チュートリアルの内容（操作感固定後に検討）
