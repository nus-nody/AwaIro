# AwaIro

1日1枚だけ、翌日まで見られない。感情の痕跡を溜めるフォトウォークアプリ。

## 開発セットアップ
詳細は [docs/manual/00-prerequisites.md](docs/manual/00-prerequisites.md) を参照。

## ビルド
- Android: `./gradlew :composeApp:assembleDebug`
- iOS: Xcodeで `iosApp/iosApp.xcodeproj` を開いてビルド

## アーキテクチャ
Clean Architecture 3層構造（Presentation / Domain / Data）。ローカル完結。

## スプリント
| Sprint | 機能 | 状態 |
|--------|------|------|
| 0 | 基盤構築 | 🔨 進行中 |
| 1 | 記録する | 📋 計画中 |
| 2 | 現像する | 📋 計画中 |
| 3 | 渡す | 📋 計画中 |
