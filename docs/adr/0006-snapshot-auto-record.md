# ADR 0006 — Snapshot Test Auto-Record Default

- Status: Accepted
- Date: 2026-05-04
- Deciders: nusnody, Orchestrator (Claude Opus 4.7)

## Context

[ADR 0005](0005-snapshot-test-operations.md) defined the snapshot record/verify cycle assuming we'd add a `record:` flag to `assertSnapshot` calls (or wrap with `withSnapshotTesting(record: .all)`) on first run, then remove the flag for verify runs. This requires a temporary code edit per snapshot, friction-prone.

In Phase 1 and Phase 2 we discovered that **`swift-snapshot-testing` 1.19's default behavior** is `record: .missing` — i.e., when the reference snapshot file does NOT exist on disk, the library auto-records it during the test run AND fails the test (so the run is "red"); on re-run, the now-present reference is used for verification, and the test passes.

This means the operational cycle is simpler than ADR 0005 prescribed:

1. Write the new snapshot test (no `record:` flag)
2. Run xcodebuild test → fails with "snapshot recorded" message + PNG written to `__Snapshots__/`
3. Visually inspect the PNG (Quick Look / Finder)
4. Re-run xcodebuild test → passes (verify against the recorded baseline)
5. Commit test + snapshot PNG together

No flag toggling. Phase 1 (Task 9) and Phase 2 (Task 19, Task 15) all used this pattern successfully.

## Decision

**Adopt `record: .missing` (library default) as the project's snapshot test workflow.** Do not pass `record:` flags or wrap with `withSnapshotTesting(record:)` blocks in test code unless intentionally re-recording an existing snapshot.

### Standard cycle

```
write test → xcodebuild test (red, snapshot recorded) →
  eyeball PNG → xcodebuild test (green, verified) → commit test + PNG
```

### Re-recording an existing snapshot (intentional changes)

When a UI change is intentional and the existing snapshot needs updating:

**Option A (preferred):** Delete the stale PNG, run xcodebuild test (auto-records new), eyeball, re-run.

```bash
rm packages/<pkg>/Tests/<pkg>Tests/__Snapshots__/<TestSuite>/<testName>.<index>.png
xcodebuild test -scheme <pkg> -destination 'platform=iOS Simulator,name=iPhone 16 (AwaIro)' -only-testing:<pkg>Tests/<TestSuite>/<testName>
# eyeball the new PNG
xcodebuild test ... # verify
git add ...png ...swift && git commit
```

**Option B:** Add `withSnapshotTesting(record: .all) { ... }` around the affected `assertSnapshot` call temporarily. Run, eyeball, remove the wrapper, re-run, commit. Use only when the test file references many snapshots and Option A is tedious.

### CI policy (Phase 3+ when CI is added)

CI must run with `record: .never` (fail on missing snapshot) so a developer who forgot to commit the PNG is caught. Local development uses the library default.

The current Makefile (`make test-snapshot`) does NOT pass `record:`, so CI will inherit `.missing` by default — that needs to change when CI is added. Track as a Phase 3+ item: add `SNAPSHOT_TESTING_RECORD=never` env-var support to the Makefile, then set it in GitHub Actions.

## Consequences

### Positive

- Test code stays clean (no temporary `record:` flags to remember to remove)
- The "did I forget to remove the flag?" failure mode (which would silently re-record on every run, hiding actual diffs) is eliminated
- Onboarding cost is lower — implementers don't need to learn the record/verify cycle as a special procedure

### Negative

- A developer who forgets to commit a recorded PNG will see CI failures (when CI exists). Mitigation: CI policy above.
- Re-recording (Option A) requires deleting the file first — slight friction vs. just adding `record:` once

### Neutral

- This supersedes ADR 0005's "Recording cycle" section (the ADR 0005 cycle still works but is unnecessarily ceremonial). ADR 0005 remains accepted; this ADR refines step 3 of its "Recording cycle".

## Alternatives Considered

### Always use `record: .all` (force re-record every run)

- ❌ Hides actual visual regressions — every run "passes" because every run records fresh
- Categorically wrong for verification

### Always use `record: .never` (refuse to auto-record)

- ✅ Strictest reproducibility
- ❌ Adding a new snapshot test requires extra steps (manually pre-create empty PNG, OR run with record once, OR set library config inline)
- ❌ Friction for new test authoring

### Wrap each test body with `withSnapshotTesting(record: .missing) { ... }`

- ❌ Verbose (every test has the same boilerplate)
- ❌ No different from library default in behavior
- Reject in favor of just relying on default

## References

- [ADR 0005 — Snapshot Test Operations Policy](0005-snapshot-test-operations.md) (this refines step 3 of its "Recording cycle")
- [Phase 1 retro](../harness/phase1-retro.md) — initial snapshot operation observations
- [Phase 2 retro](../harness/phase2-retro.md) — confirmed pattern across 7 snapshots
- [swift-snapshot-testing API: SnapshotTestingConfiguration.Record](https://github.com/pointfreeco/swift-snapshot-testing/blob/main/Sources/SnapshotTesting/SnapshotTestingConfiguration.swift)
