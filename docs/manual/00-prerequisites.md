# 事前インストールが必要なもの一覧

Claude Code側で自動実行できない、手動インストールが必要な項目をまとめます。
Sprint 0着手前にすべて完了させてください。

---

## 必須（Sprint 0着手前）

### 1. JDK 17以上
Kotlin Multiplatformのビルドに必須。

```bash
# Homebrewでインストール
brew install openjdk@17
# 確認
java -version
```

### 2. Android Studio
- 最新版をダウンロード: https://developer.android.com/studio
- 初回起動時に「Kotlin Multiplatform Mobile」pluginをインストール
- Android SDK（API 34以上）をインストール

### 3. Xcode（Macのみ、iOSビルドに必須）
- Mac App Storeからインストール（大容量・時間がかかる）
- インストール後、`xcode-select --install` でコマンドラインツールも導入
- iOS 17シミュレータを有効化

### 4. Git + GitHub CLI
```bash
brew install git gh
# GitHub認証
gh auth login
```

### 5. Node.js（ビジュアルコンパニオン等の補助ツール用）
Compose Multiplatform本体には不要だが、Claude Codeの補助機能で使用。

```bash
brew install node
```

---

## Claude Code経由で実施できないこと一覧

| 項目 | 理由 | 対応方針 |
|------|------|----------|
| Xcodeのインストール | Mac App Store経由のため | 手動でApp Storeから |
| Android Studioのインストール | GUIインストーラー | 手動でダウンロード |
| Kotlin Multiplatform plugin有効化 | IDE操作 | Android Studio起動後に手動 |
| Apple Developer登録 | Webフォーム操作 + 支払い | 必要時に手動登録 |
| GitHub Actionsシークレット登録 | 機密情報のため | GitHub Web UIから手動設定 |
| 実機（iPhone/Android）の接続設定 | 物理操作 | 開発者モード有効化等 |
| App Store Connect / Play Console操作 | Web UIでの審査提出 | 配信時に手動 |

---

## GitHub連携について

- **現状:** Claude CodeにGitHub専用MCPツールは組み込まれていません
- **代替:** `gh` CLIコマンドをBash経由で使用します
- **必要な権限:** リポジトリのread/write, Actions, Secretsのread/write

GitHub MCP連携を追加したい場合は、Claude Codeの設定（`settings.json`）でMCPサーバーを追加してください。
