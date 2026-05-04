# 事前インストールが必要なもの一覧

iOS ネイティブ実装に必要な、Claude Code 側で自動実行できない手動インストール項目をまとめます。Phase 1 着手前にすべて完了させてください。

> このプロジェクトは 2026-05-04 に KMP（Kotlin Multiplatform）から iOS ネイティブに転換しました。KMP 時代の前提条件は `archive/kmp` ブランチに保管されています。

---

## 必須

### 1. Xcode 26 以上

Mac App Store からインストール（大容量・時間がかかる）。Swift 6 / Swift Testing が同梱されている。

```bash
# インストール後
xcode-select --install            # コマンドラインツール導入
xcode-select -p                   # 確認: /Applications/Xcode.app/Contents/Developer
xcodebuild -version               # 確認: Xcode 26.x.x
```

iOS 17 シミュレータを Xcode の Settings → Components から有効化。

### 2. macOS 14 (Sonoma) 以上

`@Observable` macro が iOS 17 / macOS 14 を最低要件とするため。

```bash
sw_vers -productVersion           # 14.x 以上であること
```

### 3. Git + GitHub CLI

```bash
brew install git gh
gh auth login                     # 初回のみ
```

---

## 推奨

### 4. swift-format（任意、コード整形）

Phase 0 のフックは未インストールでも no-op になるが、自動整形を有効にする場合は必要。

```bash
brew install swift-format
swift-format --version
```

未インストールの場合 `make lint` は警告を出してパスする。

### 5. jq（フック内 JSON パースに使用）

macOS の Xcode CLT に同梱されている (`/usr/bin/jq`)。確認:

```bash
which jq && jq --version
```

未インストールの場合は Claude Code の hooks が一部動かなくなる。

### 6. Node.js（任意、補助ツール用）

Claude Code のビジュアルコンパニオン等を使う場合のみ。本プロジェクトのビルドには不要。

```bash
brew install node
```

---

## Claude Code 経由で実施できないこと一覧

| 項目 | 理由 | 対応方針 |
|------|------|----------|
| Xcode のインストール | Mac App Store 経由 | 手動で App Store から |
| Apple Developer 登録 | Web フォーム + 支払い | 必要時に手動登録 |
| Apple Developer 証明書 / Provisioning Profile | Apple ID 認証必要 | Xcode の Signing & Capabilities から |
| GitHub Actions シークレット登録 | 機密情報のため | GitHub Web UI から手動設定 |
| 実機 (iPhone) の接続設定 | 物理操作 | 開発者モード有効化等 |
| App Store Connect 操作 | Web UI での審査提出 | 配信時に手動 |

---

## GitHub 連携について

- **現状:** `gh` CLI を Bash 経由で使用
- **必要な権限:** リポジトリの read/write, Actions, Secrets の read/write
- **MCP サーバー:** GitHub 連携 MCP を使う場合は `.claude/settings.json` で `mcpServers` に追加

---

## ビルド & テストの最初の一歩

すべてのインストールが完了したら、リポジトリ root で:

```bash
make verify     # SPM 4 パッケージを build + test + lint
```

`✅ make verify passed` が表示されれば環境構築は完了。Xcode App Target は Phase 1 で生成されるため、現時点では Xcode で開く必要はない。

詳細は [README.md](../../README.md) を参照。
