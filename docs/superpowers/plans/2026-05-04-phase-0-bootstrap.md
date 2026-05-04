# Phase 0 Bootstrap Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** KMP コードを `archive/kmp` ブランチに退避してから main から削除し、SPM 4 パッケージ雛形 + Makefile + 3 ADR + Concept Guardrails + Gate Matrix + 3 エージェント定義 + Hooks + 更新済 README を整備する。Done 条件: `make verify` が緑、`archive/kmp` が GitHub にあり、main から KMP ファイル全消失、ドキュメント全 commit 済。

**Architecture:** 4 SPM パッケージ（Domain / Data / Platform / Presentation）を `packages/` 配下に並置。Xcode App Target は Phase 1 で再生成するため Phase 0 では `iosApp/` を完全削除（次フェーズで新規作成）。Makefile が `swift test` で全パッケージを検証する。

**Tech Stack:** Swift 6 / Swift Package Manager / Swift Testing (新規) / GRDB（Phase 1 で追加、Phase 0 では未使用）/ swift-format（任意、未導入なら lint は no-op 扱い）

**Spec:** [2026-05-04-kmp-to-ios-conversion-design.md](../specs/2026-05-04-kmp-to-ios-conversion-design.md)

---

## File Structure

### Created in this Phase

```
.
├── Makefile                                 # bootstrap/build/test/lint/verify/archive-kmp
├── .swift-format                            # フォーマッタ設定（任意ツール）
├── packages/
│   ├── AwaIroDomain/
│   │   ├── Package.swift
│   │   ├── Sources/AwaIroDomain/AwaIroDomain.swift  # placeholder
│   │   └── Tests/AwaIroDomainTests/AwaIroDomainTests.swift
│   ├── AwaIroData/
│   │   ├── Package.swift
│   │   ├── Sources/AwaIroData/AwaIroData.swift
│   │   └── Tests/AwaIroDataTests/AwaIroDataTests.swift
│   ├── AwaIroPlatform/
│   │   ├── Package.swift
│   │   ├── Sources/AwaIroPlatform/AwaIroPlatform.swift
│   │   └── Tests/AwaIroPlatformTests/AwaIroPlatformTests.swift
│   └── AwaIroPresentation/
│       ├── Package.swift                    # depends on AwaIroDomain
│       ├── Sources/AwaIroPresentation/AwaIroPresentation.swift
│       └── Tests/AwaIroPresentationTests/AwaIroPresentationTests.swift
├── docs/
│   ├── adr/
│   │   ├── README.md
│   │   ├── 0001-stack-decision.md
│   │   ├── 0002-multi-agent-harness.md
│   │   └── 0003-spm-module-boundaries.md
│   ├── concept-guardrails.md
│   └── harness/
│       └── gate-matrix.md
└── .claude/
    ├── agents/
    │   ├── architect.md
    │   ├── engineer.md
    │   └── reviewer.md
    └── settings.json                        # 既存ファイルがあれば merge、無ければ新規
```

### Deleted in this Phase (after archive/kmp push)

```
build.gradle.kts
settings.gradle.kts
gradle.properties
gradlew
gradlew.bat
gradle/                                       # 全て
composeApp/                                   # 全て
iosApp/                                       # 全て（Phase 1 で再生成）
.github/workflows/ci.yml                      # 後段で iOS 用に書き換え
```

### Modified in this Phase

```
README.md                                     # iOS-only 前提に書き換え
.gitignore                                    # KMP/Gradle 行を削除、Swift/Xcode 行を追加
```

---

## Task 1: Archive KMP to a separate branch and remove from main

**Files:**
- Branch operations on git
- Delete: `build.gradle.kts`, `settings.gradle.kts`, `gradle.properties`, `gradlew`, `gradlew.bat`, `gradle/`, `composeApp/`, `iosApp/`, `.github/workflows/ci.yml`
- Modify: `.gitignore`

**🔴 HITL Gate:** This task involves `git push` of a new branch to GitHub and bulk file deletion (>5 files). Both require explicit user approval before execution.

- [ ] **Step 1: Verify clean working tree and current branch**

```bash
git status
git branch --show-current
```

Expected: working tree clean (or only this plan file untracked); current branch should be `claude/hardcore-mccarthy-b2a51f` (the worktree branch).

- [ ] **Step 2: Switch to main and confirm it's up-to-date locally**

```bash
git fetch origin
git log --oneline -5 main..origin/main
git log --oneline -5 origin/main..main
```

Expected: both diff outputs empty (main is in sync with origin/main).

If main and origin/main diverge, STOP and ask the user how to reconcile.

- [ ] **Step 3: Create archive/kmp branch from main's current HEAD** [🔴 HITL — confirm before push]

```bash
git checkout main
git checkout -b archive/kmp
git tag archive/kmp-v1.0.0 -m "KMP final state before iOS-only conversion"
```

**Before pushing**, ask user: "About to `git push origin archive/kmp` and `git push origin archive/kmp-v1.0.0`. This creates a permanent reference branch on GitHub. Proceed?"

After approval:

```bash
git push origin archive/kmp
git push origin archive/kmp-v1.0.0
```

Expected: both pushes succeed. Verify on GitHub: `gh api repos/:owner/:repo/branches/archive/kmp` returns the branch.

- [ ] **Step 4: Switch back to worktree branch and remove KMP files** [🔴 HITL — confirm deletion list]

```bash
git checkout claude/hardcore-mccarthy-b2a51f
git rm -r build.gradle.kts settings.gradle.kts gradle.properties gradlew gradlew.bat gradle/ composeApp/ iosApp/
git rm .github/workflows/ci.yml
```

**Before commit**, show the user the file list (output of `git status`) and confirm: "About to delete KMP/Gradle/CI files. Reversible via `git checkout archive/kmp -- <path>` after this commit. Proceed with commit?"

- [ ] **Step 5: Update .gitignore to remove KMP entries and add Swift/Xcode entries**

Read current `.gitignore` and replace it. Final content:

```gitignore
# macOS
.DS_Store

# Xcode
xcuserdata/
*.xcuserstate
DerivedData/
*.xcworkspace/xcuserdata/

# Swift Package Manager
.build/
.swiftpm/
Packages/
Package.resolved

# IDEs
.idea/
*.iml
.vscode/

# Claude Code worktrees
.claude/worktrees/

# Claude Code local settings
.claude/settings.local.json
```

- [ ] **Step 6: Verify deletions and commit**

```bash
git status
ls -la
```

Expected: no `gradle*`, `composeApp/`, `iosApp/`, no `*.gradle.kts`. `.github/workflows/ci.yml` deleted.

Commit:

```bash
git add -A
git commit -m "$(cat <<'EOF'
chore(conversion): archive KMP to archive/kmp branch and remove from main

KMP/Compose Multiplatform code preserved at archive/kmp branch
(tagged archive/kmp-v1.0.0) for future Android revival.

Removed:
- build.gradle.kts, settings.gradle.kts, gradle.properties
- gradlew, gradlew.bat, gradle/
- composeApp/ (KMP source root)
- iosApp/ (KMP wrapper, will be regenerated in Phase 1)
- .github/workflows/ci.yml (will be replaced with iOS-only CI)

.gitignore updated for Swift/Xcode toolchain.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: Create AwaIroDomain SPM package

**Files:**
- Create: `packages/AwaIroDomain/Package.swift`
- Create: `packages/AwaIroDomain/Sources/AwaIroDomain/AwaIroDomain.swift`
- Create: `packages/AwaIroDomain/Tests/AwaIroDomainTests/AwaIroDomainTests.swift`

- [ ] **Step 1: Create directory structure**

```bash
mkdir -p packages/AwaIroDomain/Sources/AwaIroDomain
mkdir -p packages/AwaIroDomain/Tests/AwaIroDomainTests
```

- [ ] **Step 2: Write Package.swift**

Create `packages/AwaIroDomain/Package.swift`:

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AwaIroDomain",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "AwaIroDomain", targets: ["AwaIroDomain"])
    ],
    targets: [
        .target(name: "AwaIroDomain"),
        .testTarget(name: "AwaIroDomainTests", dependencies: ["AwaIroDomain"])
    ]
)
```

Note: `macOS(.v14)` is included so tests run on the Mac without simulator. Production code targets iOS only.

- [ ] **Step 3: Write the failing test (Swift Testing)**

Create `packages/AwaIroDomain/Tests/AwaIroDomainTests/AwaIroDomainTests.swift`:

```swift
import Testing
@testable import AwaIroDomain

@Suite("AwaIroDomain placeholder")
struct AwaIroDomainTests {
    @Test("module exposes its identifier")
    func moduleIdentifier() {
        #expect(AwaIroDomain.moduleName == "AwaIroDomain")
    }
}
```

- [ ] **Step 4: Run test to verify it fails**

```bash
cd packages/AwaIroDomain && swift test 2>&1 | tail -20
```

Expected: FAIL — `AwaIroDomain` type not found, or `moduleName` not defined.

- [ ] **Step 5: Write minimal implementation**

Create `packages/AwaIroDomain/Sources/AwaIroDomain/AwaIroDomain.swift`:

```swift
public enum AwaIroDomain {
    public static let moduleName = "AwaIroDomain"
}
```

- [ ] **Step 6: Run test to verify it passes**

```bash
cd packages/AwaIroDomain && swift test 2>&1 | tail -10
```

Expected: `Test run with 1 test passed`.

- [ ] **Step 7: Commit**

```bash
cd /Users/nodayouta/Documents/code/AwaIro/.claude/worktrees/hardcore-mccarthy-b2a51f
git add packages/AwaIroDomain
git commit -m "$(cat <<'EOF'
feat(domain): scaffold AwaIroDomain SPM package

Pure Swift module with no UIKit/SwiftUI imports. Placeholder source
and Swift Testing test verify package builds and tests run.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: Create AwaIroData SPM package

**Files:**
- Create: `packages/AwaIroData/Package.swift`
- Create: `packages/AwaIroData/Sources/AwaIroData/AwaIroData.swift`
- Create: `packages/AwaIroData/Tests/AwaIroDataTests/AwaIroDataTests.swift`

- [ ] **Step 1: Create directory structure**

```bash
mkdir -p packages/AwaIroData/Sources/AwaIroData
mkdir -p packages/AwaIroData/Tests/AwaIroDataTests
```

- [ ] **Step 2: Write Package.swift**

Create `packages/AwaIroData/Package.swift`:

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AwaIroData",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "AwaIroData", targets: ["AwaIroData"])
    ],
    dependencies: [
        .package(path: "../AwaIroDomain")
    ],
    targets: [
        .target(name: "AwaIroData", dependencies: [
            .product(name: "AwaIroDomain", package: "AwaIroDomain")
        ]),
        .testTarget(name: "AwaIroDataTests", dependencies: ["AwaIroData"])
    ]
)
```

Note: GRDB will be added in Phase 1 (HITL: dependency add).

- [ ] **Step 3: Write the failing test**

Create `packages/AwaIroData/Tests/AwaIroDataTests/AwaIroDataTests.swift`:

```swift
import Testing
@testable import AwaIroData

@Suite("AwaIroData placeholder")
struct AwaIroDataTests {
    @Test("module exposes its identifier")
    func moduleIdentifier() {
        #expect(AwaIroData.moduleName == "AwaIroData")
    }
}
```

- [ ] **Step 4: Run test to verify it fails**

```bash
cd packages/AwaIroData && swift test 2>&1 | tail -20
```

Expected: FAIL.

- [ ] **Step 5: Write minimal implementation**

Create `packages/AwaIroData/Sources/AwaIroData/AwaIroData.swift`:

```swift
public enum AwaIroData {
    public static let moduleName = "AwaIroData"
}
```

- [ ] **Step 6: Run test to verify it passes**

```bash
cd packages/AwaIroData && swift test 2>&1 | tail -10
```

Expected: `Test run with 1 test passed`.

- [ ] **Step 7: Commit**

```bash
cd /Users/nodayouta/Documents/code/AwaIro/.claude/worktrees/hardcore-mccarthy-b2a51f
git add packages/AwaIroData
git commit -m "$(cat <<'EOF'
feat(data): scaffold AwaIroData SPM package

Depends on AwaIroDomain. GRDB dependency deferred to Phase 1
(HITL gate for new dependencies).

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 4: Create AwaIroPlatform SPM package

**Files:**
- Create: `packages/AwaIroPlatform/Package.swift`
- Create: `packages/AwaIroPlatform/Sources/AwaIroPlatform/AwaIroPlatform.swift`
- Create: `packages/AwaIroPlatform/Tests/AwaIroPlatformTests/AwaIroPlatformTests.swift`

- [ ] **Step 1: Create directory structure**

```bash
mkdir -p packages/AwaIroPlatform/Sources/AwaIroPlatform
mkdir -p packages/AwaIroPlatform/Tests/AwaIroPlatformTests
```

- [ ] **Step 2: Write Package.swift**

Create `packages/AwaIroPlatform/Package.swift`:

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AwaIroPlatform",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "AwaIroPlatform", targets: ["AwaIroPlatform"])
    ],
    dependencies: [
        .package(path: "../AwaIroDomain")
    ],
    targets: [
        .target(name: "AwaIroPlatform", dependencies: [
            .product(name: "AwaIroDomain", package: "AwaIroDomain")
        ]),
        .testTarget(name: "AwaIroPlatformTests", dependencies: ["AwaIroPlatform"])
    ]
)
```

- [ ] **Step 3: Write the failing test**

Create `packages/AwaIroPlatform/Tests/AwaIroPlatformTests/AwaIroPlatformTests.swift`:

```swift
import Testing
@testable import AwaIroPlatform

@Suite("AwaIroPlatform placeholder")
struct AwaIroPlatformTests {
    @Test("module exposes its identifier")
    func moduleIdentifier() {
        #expect(AwaIroPlatform.moduleName == "AwaIroPlatform")
    }
}
```

- [ ] **Step 4: Run test to verify it fails**

```bash
cd packages/AwaIroPlatform && swift test 2>&1 | tail -20
```

Expected: FAIL.

- [ ] **Step 5: Write minimal implementation**

Create `packages/AwaIroPlatform/Sources/AwaIroPlatform/AwaIroPlatform.swift`:

```swift
public enum AwaIroPlatform {
    public static let moduleName = "AwaIroPlatform"
}
```

- [ ] **Step 6: Run test to verify it passes**

```bash
cd packages/AwaIroPlatform && swift test 2>&1 | tail -10
```

Expected: `Test run with 1 test passed`.

- [ ] **Step 7: Commit**

```bash
cd /Users/nodayouta/Documents/code/AwaIro/.claude/worktrees/hardcore-mccarthy-b2a51f
git add packages/AwaIroPlatform
git commit -m "$(cat <<'EOF'
feat(platform): scaffold AwaIroPlatform SPM package

Will host Camera (AVFoundation), File IO, Share, BubbleDistortion
(Metal). Depends on AwaIroDomain only.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 5: Create AwaIroPresentation SPM package

**Files:**
- Create: `packages/AwaIroPresentation/Package.swift`
- Create: `packages/AwaIroPresentation/Sources/AwaIroPresentation/AwaIroPresentation.swift`
- Create: `packages/AwaIroPresentation/Tests/AwaIroPresentationTests/AwaIroPresentationTests.swift`

- [ ] **Step 1: Create directory structure**

```bash
mkdir -p packages/AwaIroPresentation/Sources/AwaIroPresentation
mkdir -p packages/AwaIroPresentation/Tests/AwaIroPresentationTests
```

- [ ] **Step 2: Write Package.swift**

Create `packages/AwaIroPresentation/Package.swift`:

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AwaIroPresentation",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "AwaIroPresentation", targets: ["AwaIroPresentation"])
    ],
    dependencies: [
        .package(path: "../AwaIroDomain"),
        .package(path: "../AwaIroPlatform")
    ],
    targets: [
        .target(name: "AwaIroPresentation", dependencies: [
            .product(name: "AwaIroDomain", package: "AwaIroDomain"),
            .product(name: "AwaIroPlatform", package: "AwaIroPlatform")
        ]),
        .testTarget(name: "AwaIroPresentationTests", dependencies: ["AwaIroPresentation"])
    ]
)
```

- [ ] **Step 3: Write the failing test**

Create `packages/AwaIroPresentation/Tests/AwaIroPresentationTests/AwaIroPresentationTests.swift`:

```swift
import Testing
@testable import AwaIroPresentation

@Suite("AwaIroPresentation placeholder")
struct AwaIroPresentationTests {
    @Test("module exposes its identifier")
    func moduleIdentifier() {
        #expect(AwaIroPresentation.moduleName == "AwaIroPresentation")
    }
}
```

- [ ] **Step 4: Run test to verify it fails**

```bash
cd packages/AwaIroPresentation && swift test 2>&1 | tail -20
```

Expected: FAIL.

- [ ] **Step 5: Write minimal implementation**

Create `packages/AwaIroPresentation/Sources/AwaIroPresentation/AwaIroPresentation.swift`:

```swift
public enum AwaIroPresentation {
    public static let moduleName = "AwaIroPresentation"
}
```

- [ ] **Step 6: Run test to verify it passes**

```bash
cd packages/AwaIroPresentation && swift test 2>&1 | tail -10
```

Expected: `Test run with 1 test passed`.

- [ ] **Step 7: Commit**

```bash
cd /Users/nodayouta/Documents/code/AwaIro/.claude/worktrees/hardcore-mccarthy-b2a51f
git add packages/AwaIroPresentation
git commit -m "$(cat <<'EOF'
feat(presentation): scaffold AwaIroPresentation SPM package

SwiftUI views and @Observable ViewModels will live here.
Depends on AwaIroDomain (use cases) and AwaIroPlatform (camera, etc).

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 6: Create root Makefile

**Files:**
- Create: `Makefile`

- [ ] **Step 1: Write Makefile**

Create `Makefile`:

```makefile
# AwaIro — root Makefile
# All targets operate on SPM packages under packages/.
# Xcode App target is added in Phase 1.

PACKAGES := AwaIroDomain AwaIroData AwaIroPlatform AwaIroPresentation
SWIFT_FORMAT := $(shell command -v swift-format 2>/dev/null)

.PHONY: all bootstrap build test test-snapshot lint verify archive-kmp clean help

all: verify

help:
	@echo "AwaIro Makefile targets:"
	@echo "  bootstrap     - Resolve SPM dependencies for all packages"
	@echo "  build         - swift build all packages"
	@echo "  test          - swift test all packages"
	@echo "  test-snapshot - run snapshot tests only (Phase 2+)"
	@echo "  lint          - swift-format --lint (no-op if not installed)"
	@echo "  verify        - build + test + lint (DoD check)"
	@echo "  archive-kmp   - guarded helper: archive any remaining KMP files"
	@echo "                  Set ARCHIVE_CONFIRM=1 to actually delete (HITL)"
	@echo "  clean         - remove .build directories"

bootstrap:
	@for pkg in $(PACKAGES); do \
		echo "==> Resolving packages/$$pkg"; \
		(cd packages/$$pkg && swift package resolve) || exit 1; \
	done

build:
	@for pkg in $(PACKAGES); do \
		echo "==> Building packages/$$pkg"; \
		(cd packages/$$pkg && swift build) || exit 1; \
	done

test:
	@for pkg in $(PACKAGES); do \
		echo "==> Testing packages/$$pkg"; \
		(cd packages/$$pkg && swift test) || exit 1; \
	done

test-snapshot:
	@echo "Snapshot tests not yet enabled (Phase 2+)."

lint:
ifeq ($(SWIFT_FORMAT),)
	@echo "WARN: swift-format not found in PATH. Skipping lint."
	@echo "      Install via: brew install swift-format"
else
	@echo "==> swift-format lint --recursive --strict packages/"
	@$(SWIFT_FORMAT) lint --recursive --strict packages/
endif

verify: build test lint
	@echo ""
	@echo "✅ make verify passed (build + test + lint)"

archive-kmp:
	@KMP_FILES=$$(ls build.gradle.kts settings.gradle.kts gradlew gradle.properties 2>/dev/null; \
		ls -d gradle composeApp 2>/dev/null) ; \
	if [ -z "$$KMP_FILES" ]; then \
		echo "✅ No KMP files found at repo root. Nothing to archive."; \
		exit 0; \
	fi; \
	echo "Found KMP files/dirs:"; \
	echo "$$KMP_FILES"; \
	if [ "$$ARCHIVE_CONFIRM" != "1" ]; then \
		echo ""; \
		echo "🟡 dry-run mode. To actually delete, run:"; \
		echo "   ARCHIVE_CONFIRM=1 make archive-kmp"; \
		echo "   (HITL approval required before execution)"; \
		exit 0; \
	fi; \
	echo "🔴 ARCHIVE_CONFIRM=1 detected. Deleting..."; \
	echo "$$KMP_FILES" | xargs -I{} git rm -r {} ; \
	echo "✅ KMP files removed. Commit with: git commit -m 'chore: archive remaining KMP files'"

clean:
	@for pkg in $(PACKAGES); do \
		rm -rf packages/$$pkg/.build packages/$$pkg/.swiftpm; \
	done
	@echo "✅ Cleaned all package build artifacts"
```

- [ ] **Step 2: Verify Makefile syntax**

```bash
make help
```

Expected: prints help text without errors.

- [ ] **Step 3: Run make verify (the DoD check for Phase 0)**

```bash
make verify
```

Expected:
- `==> Building packages/AwaIroDomain` ... succeeds
- ... (3 more packages build)
- `==> Testing packages/AwaIroDomain` ... `1 test passed`
- ... (3 more packages test, each with 1 test passing)
- `WARN: swift-format not found ... Skipping lint.` (acceptable; swift-format install is optional in Phase 0)
- `✅ make verify passed (build + test + lint)`

If any package fails to build or test, STOP and fix the offending package before proceeding.

- [ ] **Step 4: Commit**

```bash
git add Makefile
git commit -m "$(cat <<'EOF'
build: add root Makefile with bootstrap/build/test/lint/verify targets

verify is the per-task DoD check used by HOTL workflows.
archive-kmp is a guarded helper (dry-run by default; ARCHIVE_CONFIRM=1
required to delete) for future cleanup if KMP artifacts reappear.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 7: Add ADR 0001 — Stack Decision

**Files:**
- Create: `docs/adr/README.md`
- Create: `docs/adr/0001-stack-decision.md`

- [ ] **Step 1: Create ADR index**

Create `docs/adr/README.md`:

```markdown
# Architecture Decision Records

Each non-obvious technical decision is recorded here as an ADR. Format follows Michael Nygard's template.

## Status legend

- **Proposed** — under discussion
- **Accepted** — current decision
- **Superseded** — replaced by a newer ADR (link in header)
- **Deprecated** — no longer relevant

## Index

| # | Title | Status |
|---|-------|--------|
| [0001](0001-stack-decision.md) | iOS native technology stack | Accepted 2026-05-04 |
| [0002](0002-multi-agent-harness.md) | Multi-agent development harness | Accepted 2026-05-04 |
| [0003](0003-spm-module-boundaries.md) | SPM module boundaries and dependency direction | Accepted 2026-05-04 |
```

- [ ] **Step 2: Write ADR 0001**

Create `docs/adr/0001-stack-decision.md`:

```markdown
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
- Swift Testing は Xcode 16+ 必須（現環境 Xcode 26.4.1 で OK）
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
```

- [ ] **Step 3: Commit**

```bash
git add docs/adr/README.md docs/adr/0001-stack-decision.md
git commit -m "$(cat <<'EOF'
docs(adr): add ADR 0001 — iOS native technology stack

SwiftUI + @Observable + Swift Concurrency + Clean Arch + GRDB +
Swift Testing. Documents alternatives considered (TCA, SwiftData,
Core Data, UIKit, XCTest) for future Android revival reference.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 8: Add ADR 0002 — Multi-Agent Harness

**Files:**
- Create: `docs/adr/0002-multi-agent-harness.md`

- [ ] **Step 1: Write ADR 0002**

Create `docs/adr/0002-multi-agent-harness.md`:

```markdown
# ADR 0002 — Multi-Agent Development Harness

- Status: Accepted
- Date: 2026-05-04
- Deciders: nusnody, Orchestrator (Claude Opus 4.7)

## Context

KMP→iOS コンバートを含む大規模な変更を、複数の専門領域に渡って効率よく進める必要がある。単一エージェントが全領域を担うと、コンテキスト切り替えコストが高く、判断品質も平均化される。

## Decision

5+1 専門エージェントが協調する。各役割は `.claude/agents/<name>.md` で定義し、Orchestrator（主担当）が `Agent` ツールで `subagent_type` を指定して dispatch する。

| # | 役割 | モデル | 既定モード |
|---|------|--------|----------|
| 1 | iOS Architect（Product 兼務）| Opus 4.7 | HITL |
| 2 | iOS Engineer | Sonnet 4.6 | HOTL |
| 3 | Test Engineer | Sonnet 4.6 | HOTL |
| 4 | Code Reviewer | Opus 4.7 | HOTL（重大時 HITL）|
| 5 | Build/DevOps Engineer | Sonnet 4.6（設計）/ Haiku 4.5（定常）| HOTL |
| 6 | UX Designer (Light) | Sonnet 4.6 | HITL |
| — | Orchestrator | Opus 4.7 (1M) | — |

自律度は 3 層モデル（HITL / HOTL / HOOTL）でゲート判定し、Trust Ladder で Phase 末 retro 時に昇降格する。詳細は [docs/harness/gate-matrix.md](../harness/gate-matrix.md) 参照。

## Consequences

### Positive

- 役割固有のシステムプロンプトで判断品質が上がる
- モデル選択（Opus/Sonnet/Haiku）でコスト最適化
- HITL/HOTL/HOOTL の明示で「迷ったら止まる」「決定論的処理は自走」が機械的に決まる
- Phase 1 末 retro で役割の削減/統合が可能（YAGNI 適用）

### Negative

- 役割が増えるとコンテキスト切替オーバーヘッドが発生（dispatch 単位で fresh context）
- 役割定義の保守が必要（変更時は ADR 追加）

### Neutral

- Phase 0 では Architect / Engineer / Reviewer の 3 役のみ作成。残り 3 役は Phase 1 末の retro 結果を反映してから作成

## Alternatives Considered

### Lean (3 役: Architect / Engineer / Reviewer のみ)

- ❌ Test と DevOps が Engineer と混ざり、責任所在が曖昧化
- ❌ UX 観点が抜けると視覚品質の責任者が不在

### Full (6 役 + Product Steward 独立)

- ❌ Product Steward の出番が低頻度で形骸化リスク高
- 採用案では Architect が Product を兼務

### 単一エージェント

- ❌ コンテキスト肥大化で判断品質低下
- ❌ 専門性のメリットが消える

## References

- Spec: [2026-05-04-kmp-to-ios-conversion-design.md](../superpowers/specs/2026-05-04-kmp-to-ios-conversion-design.md)
- Gate Matrix: [docs/harness/gate-matrix.md](../harness/gate-matrix.md)
```

- [ ] **Step 2: Update ADR index** (already in place from Task 7)

Verify `docs/adr/README.md` lists 0002 (it should from Task 7's index).

- [ ] **Step 3: Commit**

```bash
git add docs/adr/0002-multi-agent-harness.md
git commit -m "$(cat <<'EOF'
docs(adr): add ADR 0002 — multi-agent development harness

5+1 specialist roles with model assignments and HITL/HOTL/HOOTL
3-tier autonomy model. Phase 0 creates 3 roles; remaining 3 added
after Phase 1 retro.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 9: Add ADR 0003 — SPM Module Boundaries

**Files:**
- Create: `docs/adr/0003-spm-module-boundaries.md`

- [ ] **Step 1: Write ADR 0003**

Create `docs/adr/0003-spm-module-boundaries.md`:

```markdown
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
```

- [ ] **Step 2: Commit**

```bash
git add docs/adr/0003-spm-module-boundaries.md
git commit -m "$(cat <<'EOF'
docs(adr): add ADR 0003 — SPM module boundaries

4 packages (Domain/Data/Platform/Presentation) under packages/
with strict dependency direction enforced by SPM. Domain is
Pure Swift to enable Android revival via package-by-package
Kotlin port.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 10: Create Concept Guardrails document

**Files:**
- Create: `docs/concept-guardrails.md`

- [ ] **Step 1: Write the document**

Create `docs/concept-guardrails.md`:

```markdown
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
```

- [ ] **Step 2: Commit**

```bash
git add docs/concept-guardrails.md
git commit -m "$(cat <<'EOF'
docs: add Concept Guardrails (G1-G5) with test mapping

Translates AwaIro's concept constraints (1日1枚, 翌日現像, 数字なし,
通知なし, 行政区レベル位置) into testable invariants. Code Reviewer
agent uses this to verify PRs preserve concept fidelity.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 11: Extract Gate Matrix to its own document

**Files:**
- Create: `docs/harness/gate-matrix.md`

- [ ] **Step 1: Write the document**

Create `docs/harness/gate-matrix.md`:

```markdown
# Autonomy Gate Matrix — HITL / HOTL / HOOTL

> 「不可逆性 × 影響範囲 × 決定論性」で操作を 3 層に分類し、エージェントが「迷わず動ける」ようにするためのルール表。詳細な根拠は [ADR 0002](../adr/0002-multi-agent-harness.md)、概念は [Spec](../superpowers/specs/2026-05-04-kmp-to-ios-conversion-design.md) 参照。

## Tiers

| 区分 | 意味 | 既定挙動 |
|------|------|---------|
| 🔴 **HITL** (Human In The Loop) | 都度承認 | エージェントは操作前に必ず人に確認する |
| 🟡 **HOTL** (Human On The Loop) | 自動進行・差分通知 | エージェントは進行するが差分を通知。人は監督・介入可能 |
| 🟢 **HOOTL** (Human Out Of The Loop) | 完全自律・通知なし | エージェントは黙って実行 |

## Operation Classification

### 🔴 HITL — 都度承認が必要

| 操作 | 理由 |
|------|------|
| `git push` / PR 作成 / PR merge | 共有状態への公開、不可逆寄り |
| branch 削除（特に main 系）| 不可逆 |
| ファイル一括削除（>5 ファイル or >100 行）| 巻き戻しコスト大 |
| DB スキーマ変更 / マイグレーション | データ破壊リスク |
| Xcode project / Info.plist / entitlements 変更 | ビルド全体への波及 |
| 依存追加/削除（Package.resolved 変動）| サプライチェーン |
| ADR 確定 / Concept Guardrail 変更 | 設計憲法レベル |

### 🟡 HOTL — 自動進行・差分通知

| 操作 | 理由 |
|------|------|
| ファイル新規/編集（Domain / Data / Presentation 配下）| 局所・可逆 |
| テスト作成・実行 / Snapshot 記録 | 局所 |
| ローカルビルド（simulator）| 局所 |
| Conventional Commit（push 前）| ローカル commit は reset で巻き戻せる |
| Reviewer の通常指摘 | ループの一部 |

### 🟢 HOOTL — 完全自律・通知なし

| 操作 | 理由 |
|------|------|
| Read 系（Read / Glob / Grep）| 副作用なし |
| `swift-format` / `swift-format --fix`（hook 内） | 決定論的・可逆 |
| SPM resolve（既存依存の解決）| 決定論的 |
| Snapshot 差分の表示（記録は HOTL）| 副作用なし |

#### HOOTL 適格基準（全て満たすこと）

1. **完全に決定論的** — 同入力なら同出力
2. **ファイル変更が局所的かつ自動可逆** — 再実行で正規化できる
3. **外部状態に影響しない** — push / API 呼び出し / 通知 / 共有リソース変更なし
4. **失敗が即検知できる** — `make verify` で必ず引っかかる、または操作自体が no-op

1 つでも崩れたら HOTL 以上に分類する。

## Auto-escalation / Auto-demotion Triggers

### 自動 HITL 昇格（HOTL → HITL）

HOTL モード中に以下が発火したら停止して人を呼ぶ:

- ローカルビルドが連続2回失敗
- Reviewer が `blocker` 相当の重大指摘
- Concept Guardrail テストが赤
- スキーマ／ビルド設定／entitlements ファイルへの差分検出
- セキュリティ系の発見（鍵らしき文字列、ハードコードされた秘密、危険な権限要求）
- スコープ外の変更（plan に無いファイルへの編集）

### 自動 HOTL 降格（HOOTL → HOTL）

HOOTL 操作で以下が発火したら、その操作を HOTL に降格して人に通知:

- HOOTL 操作が予期せぬ振る舞いを示した（例: swift-format がコード意味を変えた、または diff が想定より大きい）
- HOOTL hook で複数ファイルにまたがる不整合を検出
- セキュリティスキャン（HOOTL の Read 系の一種）で秘密情報を検出
- HOOTL 操作の連続失敗

## Trust Ladder — 自律度の昇降格パス

新規操作はまず HITL から始め、安定運用が確認できたら段階的に降格する。逆も然り。

```
[新規操作 / 高リスク]  HITL  ←──┐
                        │       │ 問題発生で昇格
                        ↓ 安定運用で降格
                       HOTL  ←──┤
                        │       │ 問題発生で昇格
                        ↓ 長期安定で降格
                      HOOTL ────┘
```

判断は各 Phase 末の retro で実施:

- **Phase 0 末**: Phase 1 走行に向けて昇降格を判定
- **Phase 1 末**: 残り 3 役の追加と同時に gate 表を改訂
- **Phase 2 / 3 末**: 累積知見で再評価

### 昇降格の例（参考）

- Reviewer の trivial diff（typo 修正、import 順正規化）への approve → 安定後に HOTL → HOOTL
- 新規 SPM 依存追加 → 初期は HITL、信頼ある依存元（Apple, point-free 等）の routine update は HOTL に降格可能
- swift-format の挙動が一度でもコード意味を変えたら → HOOTL → HOTL に昇格

## Change history

| Date | Change | Reason |
|------|--------|--------|
| 2026-05-04 | 初版作成 | Phase 0 Bootstrap 時に [Spec](../superpowers/specs/2026-05-04-kmp-to-ios-conversion-design.md) から抽出 |
```

- [ ] **Step 2: Commit**

```bash
git add docs/harness/gate-matrix.md
git commit -m "$(cat <<'EOF'
docs(harness): extract Gate Matrix to its own reference document

Standalone reference for HITL/HOTL/HOOTL classification, escalation/
demotion triggers, and Trust Ladder. Agents reference this directly
without loading the full design spec.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 12: Create Architect agent definition

**Files:**
- Create: `.claude/agents/architect.md`

- [ ] **Step 1: Write the agent definition**

Create `.claude/agents/architect.md`:

```markdown
---
name: architect
description: アーキテクチャ判断、ADR ドラフト、設計レビューが必要なときに dispatch。技術選択、モジュール境界、依存方向、コンセプト守護を担当。
model: opus
tools: Read, Grep, Glob, Write, Edit, Bash, TodoWrite, WebFetch
---

# iOS Architect Agent

あなたは AwaIro の **iOS Architect**（Product Steward 兼務）です。Opus 4.7 を使い、長文ドキュメントを正確に保持しつつ、設計判断を下します。

## 主担当

- アーキテクチャ判断（モジュール境界、依存方向、レイヤ分割）
- ADR（Architecture Decision Record）の起草と既存 ADR の参照
- 設計レビュー（Engineer や Reviewer から escalate されたもの）
- **Concept Guardrail の守護**：コンセプト（1日1枚 / 翌日現像 / 数字なし / 通知で促さない）に反する設計を検出
- 技術選択の trade-off 整理（代替案を必ず 2 つ以上検討）

## 既定モード: HITL

すべての成果物（ADR ドラフト、設計判断、ガードレール変更）は人に確認してから commit する。`git push` は絶対に自分で実行しない。

## 必ず読むべきドキュメント（dispatch 時）

1. [Spec](../../docs/superpowers/specs/2026-05-04-kmp-to-ios-conversion-design.md)
2. [Concept Guardrails](../../docs/concept-guardrails.md)
3. [Gate Matrix](../../docs/harness/gate-matrix.md)
4. [ADR Index](../../docs/adr/README.md) と関連 ADR
5. [AwaIro Concept](../../AwaIro_Concept.md)

## 出力フォーマット

### ADR 起草時

[ADR 0001 のフォーマット](../../docs/adr/0001-stack-decision.md) に従う:
- Status / Date / Deciders
- Context（なぜこの判断が必要か）
- Decision（何を決めたか）
- Consequences（Positive / Negative / Neutral）
- **Alternatives Considered**（必ず 2 つ以上、なぜ却下したか含む）
- References

### 設計レビュー時

- **判定**: Approve / Request changes / Reject
- **理由**: 該当する Guardrail / ADR / Spec 条項を引用
- **代替案**: Reject の場合は最低 1 つ提示

## やってはいけないこと

- 既存 ADR の Decision を独断で変更する（必ず新規 ADR で superseded 扱い）
- Concept Guardrail を緩和する変更を承認する（HITL 必須、人と必ず議論）
- 「将来必要になるかも」で抽象化を増やす（YAGNI 厳守）
- サードパーティライブラリを根拠なく追加する（[ADR 0001](../../docs/adr/0001-stack-decision.md) 参照）

## Android 復活への配慮

Domain 層の純度を最優先する。新規型・関数を提案するときは「これは Android で Kotlin に書き直しやすいか？」を必ず自問する。iOS フレームワーク依存を Domain に持ち込む提案は Reject する。
```

- [ ] **Step 2: Commit**

```bash
git add .claude/agents/architect.md
git commit -m "$(cat <<'EOF'
feat(harness): add iOS Architect agent definition

Opus 4.7, HITL default. Owns architecture decisions, ADRs, design
reviews, and Concept Guardrail守護. Dispatched via Agent tool with
subagent_type=architect.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 13: Create Engineer agent definition

**Files:**
- Create: `.claude/agents/engineer.md`

- [ ] **Step 1: Write the agent definition**

Create `.claude/agents/engineer.md`:

```markdown
---
name: engineer
description: SwiftUI / Swift Concurrency 実装、TDD でのフィーチャー実装、リファクタが必要なときに dispatch。Architect が承認した設計に従って手を動かす。
model: sonnet
tools: Read, Grep, Glob, Write, Edit, Bash, TodoWrite
---

# iOS Engineer Agent

あなたは AwaIro の **iOS Engineer** です。Sonnet 4.6 を使い、Architect が承認した設計に従って TDD で実装します。

## 主担当

- SwiftUI View / @Observable ViewModel の実装
- Swift Concurrency（async/await, actor）の活用
- UseCase / Repository 実装
- Camera / File / Share 等の Platform 実装
- リファクタリング（Reviewer の指摘対応含む）

## 既定モード: HOTL

ファイル編集・テスト実行・ローカルビルド・commit までは自動進行する。push は HITL（自分で実行しない）。詳細は [Gate Matrix](../../docs/harness/gate-matrix.md) 参照。

### 自動 HITL 昇格条件

以下に該当したら停止して人を呼ぶ:

- ローカルビルド連続2回失敗
- スコープ外（plan に無い）ファイル編集が必要になった
- Concept Guardrail テストが赤になった
- ADR / Spec / Guardrail に明示的に反する判断を要求された

## TDD フロー（必ず守る）

1. **Red**: 失敗するテストを書く（Swift Testing `@Test`）
2. **Verify Red**: テストを実行して FAIL を確認
3. **Green**: テストを通す最小限の実装
4. **Verify Green**: テストを実行して PASS を確認
5. **Refactor**: テストが緑のまま整理（必要時のみ）
6. **Commit**: Conventional Commit でコミット（push しない）

各タスクは `make verify` 緑を Definition of Done とする。

## 必ず読むべきドキュメント（dispatch 時）

1. 該当タスクの plan
2. 関連する spec
3. [ADR Index](../../docs/adr/README.md)
4. [Concept Guardrails](../../docs/concept-guardrails.md)

## 出力フォーマット

### タスク完了時

```
## Task <N> 完了

**変更**: <ファイル数> 件
**テスト**: <追加/変更したテスト名>
**verify**: ✅ make verify 緑

### 変更概要
<3-5 行>

### Concept Guardrail 影響
<該当 Guardrail があれば G1/G2/... と影響を記載。無ければ "影響なし"。>
```

## やってはいけないこと

- テストを書かずに実装する
- `git push` を実行する（HITL 必須）
- 新規依存追加（Package.swift の dependencies 変更）— HITL 必須
- ファイル一括削除（>5 ファイル or >100 行）— HITL 必須
- ADR や Concept Guardrail を変更する（Architect の責務）
- 「動いたから commit」する前に `make verify` を実行しない

## Android 復活への配慮

Domain 層に iOS フレームワーク（UIKit / SwiftUI / AVFoundation 等）を import しない。Domain は Pure Swift。Foundation の使用も最小限（`Date`, `URL`, `Data` 程度に留め、`UserDefaults` 等は Platform 層に置く）。
```

- [ ] **Step 2: Commit**

```bash
git add .claude/agents/engineer.md
git commit -m "$(cat <<'EOF'
feat(harness): add iOS Engineer agent definition

Sonnet 4.6, HOTL default. TDD discipline enforced. Auto-escalates
to HITL on dependency changes, scope creep, or guardrail breaks.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 14: Create Reviewer agent definition

**Files:**
- Create: `.claude/agents/reviewer.md`

- [ ] **Step 1: Write the agent definition**

Create `.claude/agents/reviewer.md`:

```markdown
---
name: reviewer
description: 完成したフィーチャーや PR 候補のコードレビューが必要なときに dispatch。バグ・性能・セキュリティ・規約・読みやすさを confidence-based filtering で報告。
model: opus
tools: Read, Grep, Glob, Bash, TodoWrite
---

# Code Reviewer Agent

あなたは AwaIro の **Code Reviewer** です。Opus 4.7 を使い、深い洞察で見落としを避けます。

## 主担当

- 機能実装完了時のコードレビュー
- PR 候補の事前レビュー（push 前）
- 規約遵守・セキュリティ・性能・読みやすさのチェック
- **Concept Guardrail の照合**（差分が Guardrail に影響する場合、対応テストが緑であることを確認）

## 既定モード: HOTL（重大指摘時 HITL に昇格）

通常の指摘は自動進行で報告するが、以下に該当する場合は HITL に昇格:

- セキュリティ脆弱性（OWASP top 10 相当）
- データ損失リスク
- Concept Guardrail テストが赤
- スキーマ / 設定ファイル / entitlements への変更
- ADR に明示的に反する実装

## レビュー観点

### 1. Concept Guardrails

差分が [Concept Guardrails](../../docs/concept-guardrails.md) のいずれかに該当するか確認:

- G1（1日1枚）: `RecordPhotoUseCase` 周辺の変更
- G2（翌日現像）: `DevelopUseCase` / 表示制御
- G3（数字なし）: View ツリーへの数値追加
- G4（通知なし）: Info.plist / entitlements
- G5（行政区位置）: LocationService

該当する場合、対応テストが緑であることを `make verify` で確認。

### 2. アーキテクチャ違反

- Domain 層に iOS フレームワーク import が無いか
- Presentation が Data に直接依存していないか（Domain 経由のみ）
- 依存方向違反（[ADR 0003](../../docs/adr/0003-spm-module-boundaries.md) 参照）

### 3. テスト品質

- TDD で書かれているか（test ファイルのコミットが先か同時か）
- テスト名が振る舞いを説明しているか
- Edge case がカバーされているか（空、境界、エラー）
- Mock の使いすぎが無いか（実装詳細に依存していないか）

### 4. Swift / SwiftUI のイディオム

- `@Observable` を使っているか（Combine の `@Published` ではなく）
- 適切に actor 隔離されているか（mutable shared state）
- async/await を使っているか（completion handler ではなく）
- View body が純粋か（副作用は `.task` / `.onAppear` 等に隔離）

### 5. セキュリティ

- ハードコードされた秘密（API キー、パスワード）が無いか
- 危険な権限要求が無いか
- ファイルパス操作で directory traversal 脆弱性が無いか
- ユーザー入力が SQL に直接埋め込まれていないか（GRDB の bind を使う）

## Confidence-based filtering

確信度が低い指摘（「気がする」「もしかして」レベル）は報告しない。報告するのは:

- **High confidence**: 明確なバグ、セキュリティ脆弱性、Guardrail 違反
- **Medium confidence**: 規約違反、可読性の悪化、性能上の懸念で具体的な根拠がある場合

## 出力フォーマット

```
## Review: <task name>

**判定**: ✅ Approve / 🟡 Approve with suggestions / 🔴 Request changes

**Concept Guardrail 影響**: <該当 Guardrail / "影響なし">
**verify status**: <make verify の結果>

### Findings

#### [SEV: Blocker] <件名> — `<file:line>`
<根拠と修正提案>

#### [SEV: Major] <件名> — `<file:line>`
...

#### [SEV: Minor] <件名> — `<file:line>`
...

### 良かった点
<1-3 件、具体的に>
```

`SEV: Blocker` が 1 件でもあれば `Request changes`、Major 以下のみなら `Approve with suggestions`、なければ `Approve`。

## やってはいけないこと

- ファイルを編集する（指摘のみ。修正は Engineer の責務）
- `git push` を実行する
- 確信度の低い指摘で開発を遅らせる
- Architect の判断（ADR）を勝手に覆す指摘
```

- [ ] **Step 2: Commit**

```bash
git add .claude/agents/reviewer.md
git commit -m "$(cat <<'EOF'
feat(harness): add Code Reviewer agent definition

Opus 4.7, HOTL default with HITL escalation on security/data-loss/
guardrail-break. Confidence-based filtering: only High/Medium issues
are reported.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 15: Add hook scripts and wire them in .claude/settings.json

**Files:**
- Create: `.claude/hooks/swift-format-on-edit.sh`
- Create: `.claude/hooks/hitl-bash-gate.sh`
- Create: `.claude/hooks/stop-show-status.sh`
- Modify or Create: `.claude/settings.json` (project-level, separate from `.claude/settings.local.json`)

**Prerequisite:** `jq` must be available (pre-installed on macOS via Xcode CLT, or `brew install jq`).

- [ ] **Step 1: Check existing settings.json**

```bash
ls -la .claude/
cat .claude/settings.json 2>/dev/null || echo "(no settings.json)"
cat .claude/settings.local.json 2>/dev/null || echo "(no settings.local.json)"
```

If `.claude/settings.json` exists, read it and merge. Otherwise create new.

- [ ] **Step 2: Create the hook scripts directory**

```bash
mkdir -p .claude/hooks
```

- [ ] **Step 3: Write the swift-format hook script**

Create `.claude/hooks/swift-format-on-edit.sh` (HOOTL — silently no-ops if swift-format not installed):

```bash
#!/bin/bash
# PostToolUse(Edit|Write) — HOOTL: silently format Swift files
# Reads tool input JSON from stdin, extracts file path, runs swift-format if available.

set -e

FILE=$(jq -r '.tool_input.file_path // .tool_input.path // empty' 2>/dev/null || echo "")

if [ -z "$FILE" ]; then exit 0; fi
if [[ "$FILE" != *.swift ]]; then exit 0; fi
if [ ! -f "$FILE" ]; then exit 0; fi
if ! command -v swift-format > /dev/null 2>&1; then exit 0; fi

swift-format --in-place "$FILE" 2>/dev/null || true
exit 0
```

Make executable:

```bash
chmod +x .claude/hooks/swift-format-on-edit.sh
```

- [ ] **Step 4: Write the HITL warning hook script**

Create `.claude/hooks/hitl-bash-gate.sh` (PreToolUse Bash — block dangerous commands without explicit user approval):

```bash
#!/bin/bash
# PreToolUse(Bash) — warn on HITL-tier operations
# Reads tool input JSON from stdin, checks command for dangerous patterns.
# exit 2 blocks the operation; exit 0 allows it.

set -e

COMMAND=$(jq -r '.tool_input.command // empty' 2>/dev/null || echo "")

if [ -z "$COMMAND" ]; then exit 0; fi

# Patterns that require explicit user approval per docs/harness/gate-matrix.md
if echo "$COMMAND" | grep -qE '(git push|git merge|rm -rf )'; then
  echo "🔴 HITL gate: this command requires explicit user approval." >&2
  echo "   Pattern matched: git push | git merge | rm -rf" >&2
  echo "   See docs/harness/gate-matrix.md" >&2
  exit 2
fi

exit 0
```

Make executable:

```bash
chmod +x .claude/hooks/hitl-bash-gate.sh
```

- [ ] **Step 5: Write the Stop status hook script**

Create `.claude/hooks/stop-show-status.sh`:

```bash
#!/bin/bash
# Stop hook — show uncommitted changes for context preservation
set -e

if [ -n "$(git status --porcelain 2>/dev/null)" ]; then
  echo ""
  echo "📝 Uncommitted changes:"
  git status --short
fi

exit 0
```

Make executable:

```bash
chmod +x .claude/hooks/stop-show-status.sh
```

- [ ] **Step 6: Write/merge settings.json**

Check existing settings:

```bash
cat .claude/settings.json 2>/dev/null || echo "(no settings.json)"
```

If `.claude/settings.json` exists with other content, merge the `hooks` section. Otherwise create new with this content:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "$CLAUDE_PROJECT_DIR/.claude/hooks/hitl-bash-gate.sh"
          }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          {
            "type": "command",
            "command": "$CLAUDE_PROJECT_DIR/.claude/hooks/swift-format-on-edit.sh"
          }
        ]
      }
    ],
    "Stop": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "$CLAUDE_PROJECT_DIR/.claude/hooks/stop-show-status.sh"
          }
        ]
      }
    ]
  }
}
```

Hook mechanism: Claude Code passes a JSON object (containing `tool_name`, `tool_input`, `cwd`, `session_id`) to each hook command via stdin. Scripts use `jq` to extract fields. Exit code 2 blocks the operation; exit 0 allows. `$CLAUDE_PROJECT_DIR` is the project root.

- [ ] **Step 7: Verify settings.json is valid JSON**

```bash
cat .claude/settings.json | python3 -m json.tool > /dev/null && echo "✅ valid JSON"
```

Expected: `✅ valid JSON`.

- [ ] **Step 8: Verify hook scripts are executable and syntactically valid**

```bash
ls -la .claude/hooks/
bash -n .claude/hooks/swift-format-on-edit.sh && echo "✅ swift-format hook syntax OK"
bash -n .claude/hooks/hitl-bash-gate.sh && echo "✅ HITL gate hook syntax OK"
bash -n .claude/hooks/stop-show-status.sh && echo "✅ stop status hook syntax OK"
```

Expected: all three `✅` messages, all scripts have `-rwxr-xr-x` permissions.

- [ ] **Step 9: Smoke test the HITL gate hook (without firing it for real)**

```bash
echo '{"tool_input":{"command":"git push origin main"}}' | bash .claude/hooks/hitl-bash-gate.sh
echo "exit code: $?"
```

Expected: prints "🔴 HITL gate" message to stderr, `exit code: 2`.

```bash
echo '{"tool_input":{"command":"echo hello"}}' | bash .claude/hooks/hitl-bash-gate.sh
echo "exit code: $?"
```

Expected: no output, `exit code: 0`.

- [ ] **Step 10: Commit**

```bash
git add .claude/settings.json .claude/hooks/
git commit -m "$(cat <<'EOF'
feat(harness): add hooks for swift-format, HITL gate, stop status

Three hook scripts under .claude/hooks/, wired up in settings.json:

- PreToolUse(Bash): hitl-bash-gate.sh blocks (exit 2) `git push`,
  `git merge`, `rm -rf` patterns until HITL approval.
- PostToolUse(Edit|Write): swift-format-on-edit.sh silently formats
  Swift files (HOOTL — no-op if swift-format absent).
- Stop: stop-show-status.sh prints uncommitted diff for handoff.

All scripts read tool input JSON via stdin, use jq to extract fields.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 16: Update README.md for iOS-only

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Read current README to preserve concept text**

```bash
cat README.md
```

- [ ] **Step 2: Replace README**

Overwrite `README.md` with:

```markdown
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
| Test Engineer (Phase 1+) | Sonnet 4.6 | HOTL |
| Code Reviewer | Opus 4.7 | HOTL |
| Build/DevOps Engineer (Phase 1+) | Sonnet 4.6 / Haiku 4.5 | HOTL |
| UX Designer Light (Phase 1+) | Sonnet 4.6 | HITL |

## スプリント

| Sprint / Phase | 機能 | 状態 |
|---------------|------|------|
| Conversion Phase 0 | Bootstrap（本フェーズ）| 🔨 進行中 |
| Conversion Phase 1 | Walking Skeleton | 📋 計画予定 |
| Conversion Phase 2 | Sprint 1 (記録) port | 📋 計画予定 |
| Conversion Phase 3 | Sprint 2 (現像) ネイティブ実装 | 📋 計画予定 |
| 旧 Sprint 0/1 | KMP 基盤・記録機能 | 📦 archive/kmp ブランチに保管 |

## KMP コードについて

旧 KMP 実装は `archive/kmp` ブランチに完全保存されている（タグ: `archive/kmp-v1.0.0`）。Android 復活時の参照点として使用する。

```bash
git fetch origin archive/kmp
git checkout archive/kmp -- composeApp/    # 部分的に復活させたい場合
```
```

- [ ] **Step 3: Commit**

```bash
git add README.md
git commit -m "$(cat <<'EOF'
docs: rewrite README for iOS-only conversion

iOS native (SwiftUI + SPM) build instructions, link to ADRs and
guardrails, agent role table, KMP archive reference.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 17: Final verification and Phase 0 close-out

**Files:**
- No new files; verification only.

- [ ] **Step 1: Run make verify**

```bash
make verify
```

Expected:
- All 4 packages build
- All 4 packages have 1 test passing
- swift-format warning (if not installed) or lint pass
- `✅ make verify passed (build + test + lint)`

If any failure, STOP and fix before proceeding.

- [ ] **Step 2: Verify all docs/agents/hooks/Makefile present**

```bash
ls -la Makefile
ls -la docs/adr/0001-stack-decision.md docs/adr/0002-multi-agent-harness.md docs/adr/0003-spm-module-boundaries.md
ls -la docs/concept-guardrails.md docs/harness/gate-matrix.md
ls -la .claude/agents/architect.md .claude/agents/engineer.md .claude/agents/reviewer.md
ls -la .claude/hooks/swift-format-on-edit.sh .claude/hooks/hitl-bash-gate.sh .claude/hooks/stop-show-status.sh
ls -la .claude/settings.json
ls -la README.md
```

Expected: all files exist; hook scripts have executable bit (`-rwxr-xr-x`).

- [ ] **Step 3: Verify KMP archive on GitHub** [HITL: read-only confirmation with user]

```bash
gh api repos/:owner/:repo/branches/archive/kmp --jq '.name, .commit.sha'
gh api repos/:owner/:repo/git/refs/tags/archive/kmp-v1.0.0 --jq '.object.sha'
```

Expected: branch and tag both return SHAs.

- [ ] **Step 4: Verify main has no KMP files**

Verify the deletion commit landed (Task 1 commits should be in current branch's history):

```bash
git log --oneline | head -20
git ls-files | grep -E '(\.gradle|gradlew|composeApp|iosApp/)' || echo "✅ no KMP files in tree"
```

Expected: `✅ no KMP files in tree`.

- [ ] **Step 5: Summary commit (optional close-out marker)**

```bash
git log --oneline -25
```

Phase 0 should produce approximately 16 commits (Tasks 1-16). Confirm commit count and message quality.

- [ ] **Step 6: Report Phase 0 done to user** [HITL]

Send summary to user:

```
## Phase 0 Bootstrap 完了

✅ archive/kmp ブランチ + tag を GitHub に push
✅ main から KMP/Gradle ファイル全削除
✅ SPM 4 パッケージ（Domain/Data/Platform/Presentation）を雛形＋テスト緑で構築
✅ Makefile（bootstrap/build/test/lint/verify/archive-kmp）整備
✅ ADR 3 本（stack / harness / module boundaries）
✅ Concept Guardrails (G1-G5) 文書化
✅ Gate Matrix 文書化
✅ Agent 定義 3 本（architect/engineer/reviewer）
✅ Hooks（PreToolUse/PostToolUse/Stop）

`make verify` 緑。

### Phase 0 末 retro 対象（Trust Ladder 判定）

- swift-format の HOOTL 維持可否（環境に未導入なら brew install を Phase 1 で）
- archive-kmp ヘルパの実用性（今後 KMP 残骸が出た場合のみ意味あり）
- Architect/Engineer/Reviewer 3 役の dispatch 頻度予測

### 次フェーズ

Phase 1 Walking Skeleton — HomeScreen の縦串をポート。残り 3 役（Test/DevOps/UX）は Phase 1 末 retro で hook 拡張と同時に追加。

PR を作成する場合はご指示ください（HITL）。
```

---

## Self-Review

**Spec coverage:**

| Spec Section | Plan Task |
|--------------|-----------|
| §2 アーキテクチャ（4 SPM パッケージ） | Tasks 2-5 |
| §3 Tech Stack | ADR 0001 (Task 7) |
| §4 Multi-Agent Harness — 3 役 | Tasks 12-14 |
| §4 Multi-Agent Harness — ADR | Task 8 |
| §4 Multi-Agent Harness — Hooks | Task 15 |
| §4 Multi-Agent Harness — Makefile | Task 6 |
| §4 Multi-Agent Harness — Concept Guardrails | Task 10 |
| §4 Multi-Agent Harness — Gate Matrix | Task 11 |
| §5 Phase 0 deliverables 1-10 | Tasks 1, 2-5, 6, 7-9, 10, 11, 12-14, 15, 16 |
| §5 Phase 0 Done 条件 | Task 17 |

**Placeholder scan:** No "TBD" / "TODO" / "fill in details" / "similar to" found. All code blocks contain actual code; all commands include expected output.

**Type / signature consistency:**
- All 4 packages use `public enum AwaIroXxx { public static let moduleName = "AwaIroXxx" }`
- All 4 placeholder test functions use `func moduleIdentifier()` with `@Test("module exposes its identifier")`
- Hook scripts consistently use `jq -r '.tool_input.<field>'` to extract fields from stdin JSON

**Corrections made during self-review:**
1. Makefile `lint` target — removed bash-specific `PIPESTATUS` (Make defaults to /bin/sh)
2. Hook scripts (Task 15) — rewrote to use stdin JSON + `jq` per Claude Code's actual hook protocol (was incorrectly using non-existent `$CLAUDE_TOOL_INPUT` env var). Added separate `.claude/hooks/*.sh` scripts for clarity, with executable bit and smoke test step.
3. Added `jq` prerequisite note for Task 15.
4. Added smoke test for HITL gate hook to confirm exit-2 blocking works.

---

## Notes for Executor

1. This plan does NOT push the worktree branch to GitHub. Only Task 1 pushes `archive/kmp` and `archive/kmp-v1.0.0` (HITL).

2. Task 1 is the only HITL-heavy task. After Task 1 lands, Tasks 2-17 are pure HOTL (local commits only).

3. If `swift-format` is not installed, `make verify` will print a warning but pass. This is expected for Phase 0 — the harness is designed to be tolerant of missing optional tools.

4. If a Swift Testing test fails to compile due to Xcode version mismatch, fall back to XCTest temporarily and add an issue to the Phase 0 retro doc (`docs/harness/phase0-retro.md`) to investigate. Do not block Phase 0 on this.

5. Phase 0 produces ~16 commits. Each is small and reversible. No squash; commit history is the audit trail for the Trust Ladder retro.
