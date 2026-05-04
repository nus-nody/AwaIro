# Phase 2 Retro — Sprint 1 Record

**Date:** 2026-05-04
**Participants:** nusnody, Orchestrator (Claude Opus 4.7)
**Phase 2 plan:** [2026-05-04-phase-2-record.md](../superpowers/plans/2026-05-04-phase-2-record.md)
**Phase 2 commit range:** `8988a13..8d15513` (Phase 2 plan + 19 implementation commits)

## What worked

- **Hybrid execution model (orchestrator + subagents)** — Tasks 1-2/3-7/10-12/13-15 dispatched to subagents, sensitive-file edits (Package.swift, project.pbxproj) handled by orchestrator. Worked well overall; subagents stopped midway twice (Task 3, Task 15) but state was clean enough to pick up inline
- **Bypass marker (`.bypass-next-edit`)** — Used 3 times for Package.swift / project.pbxproj edits. One-shot consumption protected against accidental reuse
- **Closure-based camera dep in HomeViewModel** — Keeping the VM's camera dep as `@Sendable () async throws -> Data` instead of `any CameraController` let the VM stay testable on macOS. AppContainer wires `{ try await cameraRef.capture() }` at construction
- **HomeContentView generic over Bubble: View** — Snapshot tests inject placeholders; production injects live BubbleCameraView. Same shape, different content
- **Plan deviation: AVFoundationCameraController as final class** instead of actor. Swift 6 strict concurrency forbids @MainActor property capture from actor init. The `final class @unchecked Sendable + @MainActor init` pattern is cleaner since AVCaptureSession is Apple-documented thread-safe anyway
- **Snapshot record automation** — swift-snapshot-testing 1.19's default `record:.missing` auto-records on first run. No need for explicit `record:.all` flag in test code → simpler ADR 0005 cycle (run, eyeball, re-run for verify)

## What didn't (friction points)

- **Subagent termination mid-batch** — Twice the subagent stopped after writing tests but before implementing/committing. Solution explored: smaller batches OR inline takeover when state is clean
- **`.process("Effects")` resource path was the real culprit** — initially blamed extension visibility, but post-Phase-2 investigation (retro item E) showed swift-format's `NoAccessLevelOnExtensionDeclaration` rule auto-formatted `public extension` → `extension { public func }`, and the cross-module visibility is identical between the two forms. The actual cause of the "value has no member" error was that BubbleDistortion.swift was bundled as a Resource (not Source) due to `.process("Effects")` matching the whole directory. Fix: `.process("Effects/BubbleDistortion.metal")`
- **`resources: [.process("Effects")]`** treats every file in Effects/ as a resource, including BubbleDistortion.swift (which should be source). Fixed to `.process("Effects/BubbleDistortion.metal")`
- **`@MainActor` cross-context closure call** — HomeScreen.onCaptured needed `@MainActor` annotation AND `await` at the call site
- **Simulator camera UX** — Empty AVCaptureVideoPreviewLayer renders the wrapping UIView's default backgroundColor (white) — looked identical to Phase 1 placeholder until backgroundColor = .black was set
- **Codesign double-signing** of SPM resource bundle when not clean-rebuilt. Needed `rm -rf build/` (HITL bypass for .gitignored artifact)

## Trust Ladder decisions

| 操作 | Phase 2 末の判断 | 根拠 |
|------|--------------|------|
| `make verify` (HOOTL) | 維持 | 全フェーズ安定動作 |
| `swift-format` 自動適用 (HOOTL) | 維持 | コード意味変更ゼロ |
| `Conventional Commit` (HOTL) | 維持 | trailer 抜け事故ゼロ。HOOTL 検討は Phase 3 末で |
| Snapshot 初回 record (auto via record:.missing) | HOOTL 候補に格上げ検討 | swift-snapshot-testing が安全に振る舞う |
| Bypass marker for sensitive Edit | 継続使用 | 3 回使用で全て consume されて事故なし |

## Plan deviations

| Task | 計画 | 実装 | 理由 |
|------|------|------|------|
| Task 7 | `actor AVFoundationCameraController` | `final class @unchecked Sendable` with `@MainActor init` | Swift 6 strict concurrency: actor init can't capture @MainActor stored property |
| Task 8 | `resources: [.process("Effects")]` | `.process("Effects/BubbleDistortion.metal")` | .swift も resource 扱いで source として compile されない |
| Task 8 | `extension View { public func ... }` | `extension View { public func ... }`（plan 通り、auto-formatter で固定）| 当初 `public extension` への変更が必要と判断したが、retro item E で誤りと判明（真因は resource path）|
| Task 9 | 専用 shader snapshot test | 削除（HomeScreen snapshot で間接 cover）| YAGNI / 視覚 regression リスク低 |
| Task 13 | `.accessibilityAddTraits(.isButton)` | `SwiftUI.AccessibilityTraits.isButton` 明示 | UIKit と曖昧 |
| Task 15 | `onCaptured: (URL, Date) -> Void` | `@MainActor (URL, Date) -> Void` + `await` | Swift 6 actor 境界 |
| Task 17 | Info.plist 編集経由 | `INFOPLIST_KEY_NSCameraUsageDescription` build setting 経由 | project が GENERATE_INFOPLIST_FILE = YES |

## Spec / ADR updates needed

- **ADR 0006 候補**: Snapshot test auto-record default を codify
- **ADR 0007 候補**: AVFoundation actor → final class pattern を policy 化
- **CLAUDE.md update**: `extension X { public func }` の visibility 罠を注記

## Phase 3 entry blockers

- **AVFoundation on Simulator**: 実カメラがないので record flow は手動完全検証不可。Phase 3 で `#if targetEnvironment(simulator)` の fake camera を入れるか、device build を CI に組み込むか検討
- **Sprint 2 (現像) が次フェーズ**: Phase 2 より小さい（Domain + Presentation 中心、Camera/Metal 不要）

## Process improvements for Phase 3

- **Subagent 1 dispatch あたり 2-3 タスク以下** に抑える（premature termination 対策）
- **Pre-flight check**: 新規 public API 追加時に extension 自体の visibility を確認
- **`make clean-build` Makefile target** を Phase 3 開始前に追加検討
- **swift-format strict warning** で extension visibility のような問題が早く出ないか調査

## References

- Spec: [2026-05-04-kmp-to-ios-conversion-design.md](../superpowers/specs/2026-05-04-kmp-to-ios-conversion-design.md)
- Phase 1 retro: [phase1-retro.md](phase1-retro.md)
- Phase 2 plan: [2026-05-04-phase-2-record.md](../superpowers/plans/2026-05-04-phase-2-record.md)
- Phase 2 screenshot: [docs/snapshots/phase-2/home-bubble-iphone16.png](../snapshots/phase-2/home-bubble-iphone16.png)
- ADR 0005 (snapshot ops): [0005-snapshot-test-operations.md](../adr/0005-snapshot-test-operations.md)
