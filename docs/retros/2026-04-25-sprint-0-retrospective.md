# Sprint 0 レトロスペクティブ
**日付**: 2026-04-25  
**Sprint**: 0 — Foundation  
**目標**: Android / iOS 両プラットフォームで "AwaIro - Sprint 0 Foundation OK" を表示できる土台を作る

---

## 1. Sprint 0 の成果（Done）

| # | 成果物 | 状態 |
|---|--------|------|
| 1 | KMP プロジェクト構造（commonMain / androidMain / iosMain） | ✅ |
| 2 | Clean Architecture レイヤー（domain / data / presentation） | ✅ |
| 3 | SQLDelight スキーマ（Photo テーブル） | ✅ |
| 4 | Koin DI（共通 appModule + Android / iOS 別 platformModule） | ✅ |
| 5 | expect/actual（DatabaseFactory, ShareService, FirstLaunchGate） | ✅ |
| 6 | Android エミュレーター（Pixel 7 API35）で動作確認 | ✅ |
| 7 | iOS シミュレーター（iPhone 16 / iPhone 17）で動作確認 | ✅ |
| 8 | GitHub Actions CI（Android assembleDebug + iOS framework link） | ✅ GREEN |
| 9 | タグ `v0.1.0-sprint0` / `v0.1.0-sprint0-ios-fix` プッシュ | ✅ |

---

## 2. うまくいったこと（Keep）

- **Android ビルドは比較的スムーズ** に通った。Koin + SQLDelight + KMP の組み合わせは構造として機能した。
- **CI 設計（GitHub Actions）が初回から GREEN** になった。`linkDebugFrameworkIosSimulatorArm64` を iOS ジョブに使うパターンは有効。
- **クラッシュログからの原因特定**が的確にできた。スタックトレースの `PlistSanityCheck` → `UIApplicationSceneManifest` という読み方は再現性がある。
- **段階的コミット** で変更の粒度が追いやすかった。

---

## 3. 問題になったこと（Problem）

### 3-1. Xcode プロジェクト設定の初期不備（4件）

| 問題 | 根本原因 | 修正内容 |
|------|----------|---------|
| `Unknown iOS platform: 'macosx'` | Xcode 26 は xcodebuild に `SDK_NAME=macosx` を渡す仕様変更 | Gradle ビルドフェーズスクリプトで `SDK_NAME` を `iphonesimulator` にリマップ |
| `You have sandboxing for user scripts enabled` | Xcode 15 以降のデフォルトが `ENABLE_USER_SCRIPT_SANDBOXING=YES` | `ENABLE_USER_SCRIPT_SANDBOXING = NO` を明示 |
| `xcodebuild: Unable to find a destination matching...` | `SDKROOT` が未設定のため Xcode がシミュレーターを destination として認識しない | `SDKROOT = iphoneos` を Debug / Release 両方に追加 |
| SQLite3 リンカエラー（Undefined symbols: `_sqlite3_*`） | SQLDelight native driver がシステム SQLite3 を要求するが `-lsqlite3` が未指定 | `OTHER_LDFLAGS` に `"-lsqlite3"` を追加 |

### 3-2. Compose Multiplatform 非互換クラッシュ（2件）

| 問題 | 根本原因 | 修正内容 |
|------|----------|---------|
| `ContentView` で `UIViewControllerRepresentable` / `UIViewController` が見つからない | `import UIKit` が欠如 | `#if canImport(UIKit)` ガードで `import UIKit` を追加 |
| `PlistSanityCheck` → SIGABRT クラッシュ | `INFOPLIST_KEY_UIApplicationSceneManifest_Generation = YES` が Scene-based lifecycle を Info.plist に生成し、Compose UI が起動時に検出してクラッシュ | Debug / Release 両設定からキーを削除 |

### 3-3. 環境セットアップの手作業コスト

| 項目 | 発生理由 |
|------|---------|
| Android SDK / AVD 構築に複数ステップ | `local.properties` の sdk.dir 設定、cmdline-tools の手動ダウンロード、ライセンス承認、AVD 作成 |
| iOS シミュレーター 8.46GB ダウンロード | iOS 26.4.1 ランタイムが未インストール |
| Gradle wrapper の手動生成 | `composeApp/` ディレクトリが存在しない状態でプロジェクトを開始 |

---

## 4. 改善策（Try）

### Sprint 計画フェーズへの反映

| 改善策 | 目的 |
|--------|------|
| **新 Xcode プロジェクト作成時のチェックリスト化** | `SDKROOT`・`ENABLE_USER_SCRIPT_SANDBOXING`・`UIApplicationSceneManifest` の設定漏れを防ぐ（下記参照） |
| **KMP テンプレートに Compose 用 Info.plist 設定を文書化** | `PlistSanityCheck` クラッシュは KMP + Compose の組み合わせで必ず踏む地雷 |
| **環境セットアップ手順を README に記述（Enabler タスク）** | 次回オンボーディング時間を削減 |
| **CI に smoke test（起動確認）を追加** | `xcrun simctl launch` で起動成否を CI で検証できれば早期検出可能 |

### Xcode プロジェクト作成チェックリスト（次 Sprint 以降の定番）

```
[ ] SDKROOT = iphoneos                               (Target > Build Settings)
[ ] ENABLE_USER_SCRIPT_SANDBOXING = NO               (Target > Build Settings)
[ ] INFOPLIST_KEY_UIApplicationSceneManifest_Generation を削除  (Compose 非互換)
[ ] OTHER_LDFLAGS に -lsqlite3 を追加                (SQLDelight native driver)
[ ] Gradle build phase スクリプトに Xcode 26 SDK_NAME ワークアラウンドを含める
[ ] import UIKit を #if canImport(UIKit) でガード    (ContentView)
```

---

## 5. クラッシュ診断ノウハウ（次回以降の参考）

### PlistSanityCheck クラッシュの読み方

```
Thread N Crashed:
  → PlistSanityCheck.performIfNeeded   ← Compose が Info.plist をチェック
  → ExceptionObjHolder::Throw
  → abort
```

**意味**: `Info.plist` に `UIApplicationSceneManifest` が存在し、  
`UIWindowSceneSessionRoleApplication` が設定されている = Scene lifecycle が有効になっている  
**修正**: `INFOPLIST_KEY_UIApplicationSceneManifest_Generation` を削除

### SQLite3 リンカエラーの読み方

```
Undefined symbols for architecture arm64:
  "_sqlite3_bind_blob" referenced from: ComposeApp[...]
```

**意味**: `sqldelight:native-driver` が要求するシステム SQLite3 が未リンク  
**修正**: `OTHER_LDFLAGS = ("-lsqlite3")`

### xcodebuild destination エラーの読み方

```
Unable to find a destination matching the provided destination specifier
Available destinations: { platform:macOS, ... }
```

**意味**: `SDKROOT` が未設定で Xcode が macOS SDK をデフォルト使用  
**修正**: `SDKROOT = iphoneos` を Target build settings に追加

---

## 6. 技術的負債（Sprint 1 以降で対処）

| 負債 | 優先度 | 理由 |
|------|--------|------|
| `git config --global user.name / user.email` 未設定 | 低 | コミットの `Committer` が hostname になっている |
| Xcode MCP（`xcrun mcpbridge`）の動作未確認 | 中 | IDE 操作の自動化に使いたいが tools が load されない |
| CI に iOS simulator 起動テスト未追加 | 中 | クラッシュが CI で検出できない |
| `HomeScreen` がハードコードテキストのみ | — | Sprint 1 で置き換え予定（設計済み） |

---

## 7. Sprint 0 の振り返りサマリー

**問題の多くは「KMP + Compose + Xcode 26」という新しい組み合わせ特有のもの**だった。  
個別には既知の問題だが、組み合わせることで複数が同時に発生した。

- Xcode 26 の挙動変化（SDK_NAME、Sandboxing）→ **公式ドキュメント追従不足**
- Compose Multiplatform の制約（PlistSanityCheck）→ **KMP テンプレートとの差異を事前確認すべきだった**
- SQLite3 リンク漏れ →  **native-driver の依存関係を README で確認すれば防げた**

次の Sprint では **「動くことが分かっている土台」** の上で機能を積むため、  
同種の環境問題は発生しない。機能実装の品質とテストに集中できる。

---

## 8. Sprint 1 へのインプット

**Sprint 1 スコープ: Record（写真撮影）**

### 実装予定
- `RecordPhotoUseCase`（1日1枚制限ロジック）
- `CaptureScreen`（カメラ起動 → 撮影 → 保存）
- `PhotoRepositoryImpl`（SQLDelight 実装）
- EXIF ストリップ（`expect/actual`）
- カメラパーミッション（Android: `CAMERA`、iOS: `NSCameraUsageDescription`）

### Enabler タスク（開発開始前に設定が必要なもの）
- [ ] `git config --global user.name "Your Name"` / `user.email "email"` の設定
- [ ] Android エミュレーター（Pixel 7 API35 AwaIro）が起動していることを確認
- [ ] iOS シミュレーター（iPhone 16 or 17）が起動していることを確認

---

*AwaIro Project Log — Sprint 0 完了: 2026-04-25*
