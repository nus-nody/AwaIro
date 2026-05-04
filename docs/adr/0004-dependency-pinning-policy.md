# ADR 0004 — Dependency Pinning Policy

- Status: Accepted
- Date: 2026-05-04
- Deciders: nusnody, Orchestrator (Claude Opus 4.7)

## Context

Phase 1 で初の外部依存（GRDB.swift と swift-snapshot-testing）を導入する。SwiftPM は `from:`（範囲指定 / SemVer 互換）と `exact:`（厳密固定）の 2 つの主な version 指定方式を提供する。Phase 1 開始前に、いつどちらを使うかのポリシーを決めておく必要がある。背景に **Android 復活時に依存を Kotlin 側に翻訳する作業**が想定されるため、依存はできるだけ少なく・安定していることが望ましい。

## Decision

### 既定ポリシー: `from:` 範囲指定（SemVer 互換）

新規依存追加時、明確な理由がない限り `from: "X.0.0"` を使う。SwiftPM は SemVer 解釈で次の major までを許容する。

```swift
.package(url: "https://github.com/groue/GRDB.swift", from: "7.0.0"),
.package(url: "https://github.com/pointfreeco/swift-snapshot-testing", from: "1.16.0")
```

`Package.resolved` が pinned version を記録するので、再現性は担保される。

### `exact:` を使う条件

以下のいずれかに該当する場合のみ `exact:` で固定する:

1. **既知の互換性問題**: 新しい patch / minor で実害のある regression が報告されている
2. **API の挙動依存**: ライブラリの暗黙的な振る舞いに依存しており、minor update で挙動が変わるリスクがある
3. **Snapshot テストの安定性**: rendering 系ライブラリ（swift-snapshot-testing 等）で minor update が snapshot 差分を生む可能性がある場合

`exact:` を使うときは Package.swift に `// pinned: <理由>` のコメントを必須とする:

```swift
// pinned: 1.18.x で snapshot 出力が変わるため一時固定 (2026-MM-DD, GitHub issue #NNN)
.package(url: "https://github.com/pointfreeco/swift-snapshot-testing", exact: "1.17.0")
```

### Update のオペレーション

1. 定期的（Phase 末 retro 時）に `swift package update` を **dry-run で確認**:
   ```bash
   for pkg in packages/*/; do
     echo "=== $pkg ==="
     (cd "$pkg" && swift package update --dry-run 2>&1 | tail -5)
   done
   ```

2. 更新候補があれば各依存ごとに **HITL で承認**を取り、1 依存 = 1 commit で更新:
   ```bash
   cd packages/AwaIroData && HITL_BYPASS=1 swift package update GRDB.swift
   git add Package.resolved
   git commit -m "chore(data): bump GRDB.swift to X.Y.Z"
   ```

3. 更新後は `make verify` 緑を確認してから push（HITL）。

### Trust Ladder（ADR 0002 と整合）

- **初回追加**: HITL（spec / ADR 0001 で言及されない依存は Architect レビューも）
- **routine update**: 信頼ある依存元（Apple、point-free、GRDB 等）の patch / minor 更新は将来 HOTL に降格可。現時点では HITL 維持

## Consequences

### Positive

- 再現性は `Package.resolved` で担保しつつ、致命的な脆弱性 patch は `swift package update` で自然に取り込める
- pin する場合は理由が必須 → 後から「なぜ pin したか」が読める
- 依存が少ないので update 監視のコスト自体が小さい

### Negative

- `from:` を使う以上、minor update が破壊的でないことを上流に依存する
- 上流が SemVer を厳密に守っていない依存（特に 0.x 系）では事故リスク
- update のたびに HITL 承認が要る → 軽い摩擦

### Neutral

- 0.x 系依存（`from: "0.x.0"` は危険）は今後検討時に注意。Phase 1 で導入する 2 依存は両方 1.x / 7.x で安定枠

## Alternatives Considered

### 全依存を `exact:` で固定

- ✅ 完全な再現性
- ❌ 脆弱性 patch を取り込むのに毎回手動更新が必要
- ❌ Package.swift に大量の version リテラルが散る
- ❌ `Package.resolved` で十分な再現性を既に得られている

### `branch:` / `revision:` 指定

- ✅ 特定のフォーク / 未リリース版を使える
- ❌ 上流追従が手動になる
- ❌ サプライチェーンセキュリティ上のリスク（branch は force-push される可能性）
- 採用条件: 公式 release では入手できない緊急 patch を当てる必要がある時のみ、commit ハッシュで pin

### 依存を一切入れない（自前実装）

- ✅ 究極の再現性
- ❌ GRDB / snapshot テストの再発明はオーバーキル
- ❌ Domain は Pure Swift だが、Data / Presentation は実用的依存に頼る方が筋が良い

## References

- [ADR 0001 — iOS Native Technology Stack](0001-stack-decision.md)
- [ADR 0002 — Multi-Agent Development Harness](0002-multi-agent-harness.md)
- [Gate Matrix](../harness/gate-matrix.md)
- [Phase 0 Retro](../harness/phase0-retro.md)
- [SwiftPM Package Description](https://docs.swift.org/package-manager/PackageDescription/PackageDescription.html)
