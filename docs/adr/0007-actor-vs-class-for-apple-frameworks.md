# ADR 0007 — `actor` vs `final class` for Wrapping Apple Framework Types

- Status: Accepted
- Date: 2026-05-04
- Deciders: nusnody, Orchestrator (Claude Opus 4.7)

## Context

Phase 2 specified `AVFoundationCameraController` as a Swift `actor` (consistent with the convention "wrap mutable shared state with actor for isolation"). The implementation hit a Swift 6 strict concurrency wall: `previewLayer` is an `@MainActor`-isolated stored property (because `AVCaptureVideoPreviewLayer` is a `CALayer` subclass that must be created and accessed on the main thread), but the actor's `init` is isolated to the actor itself, NOT to MainActor. The compiler refused to let init reference / initialize `previewLayer`.

Workaround attempts:
- `Task { @MainActor in ... }` inside init: still couldn't capture self's @MainActor properties
- `nonisolated(unsafe) let previewLayer`: drops safety
- Lazy main-actor initialization via a separate setup method: ergonomically poor (caller must remember to call it)

The shipped solution: wrap as `final class @unchecked Sendable` with `@MainActor init`. This works because:
- A class init can be `@MainActor`-annotated; the body runs on main actor and can initialize @MainActor stored properties along with non-isolated ones
- Apple documents `AVCaptureSession`, `AVCaptureVideoPreviewLayer`, `AVCapturePhotoOutput`, etc. as **thread-safe** for the operations we use (configuration changes, start/stop, capture). So `@unchecked Sendable` is honest here, not a lie.
- `final class` matches the "reference type with identity" semantics that Apple-framework wrappers naturally have (one CameraController per app, holds long-lived AVCaptureSession)

## Decision

When wrapping an Apple framework type that:

1. **Has at least one `@MainActor`-isolated property** (typically anything ending in Layer / View / ViewController, or anything documented as "main-thread-only"), AND
2. **Is documented as thread-safe by Apple** (or has thread-safety guarantees you've verified by reading the docs)

→ **Use `final class @unchecked Sendable + @MainActor init`** instead of `actor`.

When wrapping a type that is **NOT thread-safe** (most pure-data types are fine; some framework types need strict isolation), use `actor` and accept that any @MainActor properties must be accessed via `await MainActor.run { ... }` or surfaced through an async API. Avoid mixing `actor` and `@MainActor` properties.

### Decision tree

```
Need to wrap an Apple framework type?
├── Has @MainActor properties? (Layer / View / etc.)
│   ├── Yes → Apple-documented thread-safe?
│   │   ├── Yes → final class @unchecked Sendable + @MainActor init   ← THIS POLICY
│   │   └── No → Restructure: separate the @MainActor parts into a
│   │              standalone class, wrap the rest with actor
│   └── No → Use actor (standard concurrency idiom)
└── Pure value semantics? → Use struct (preferred for value types)
```

### `@unchecked Sendable` discipline

Using `@unchecked Sendable` is a **promise** that you've verified the underlying API's thread safety. Add a comment near the declaration documenting WHY:

```swift
/// AVFoundation-backed CameraController. AVCaptureSession is documented as
/// thread-safe by Apple (see [link to docs]), so we use a final class with
/// @unchecked Sendable rather than an actor — this lets us initialize
/// previewLayer (@MainActor) in the init body without async hops.
public final class AVFoundationCameraController: CameraController, @unchecked Sendable {
    ...
}
```

Reviewer agent should flag any `@unchecked Sendable` that lacks this rationale.

## Consequences

### Positive

- The init body is straightforward: no Task hops, no lazy initialization protocols
- Caller API stays simple: no need for an `async setup()` step before usage
- Works cleanly with SwiftUI `UIViewRepresentable` (which consumes `@MainActor` properties directly)
- Doesn't compromise actual thread safety because Apple already provides it

### Negative

- Loses compile-time concurrency checking that `actor` provides — relies on the developer's correct read of Apple docs
- `@unchecked Sendable` is a known "escape hatch" that future maintainers might over-apply if not careful
- Slight semantic mismatch: an "actor in spirit but a class in letter" can confuse readers expecting `actor`

### Neutral

- This pattern is what Apple itself uses internally for many framework types (verified by spelunking Apple's Swift overlays)

## Alternatives Considered

### Pure `actor` with separate @MainActor coordinator

```swift
public actor AVFoundationCameraController { ... }
@MainActor public final class CameraPreviewCoordinator { ... }
```

Caller wires both together. Two types, more setup, ergonomically worse. Rejected.

### `MainActor.assumeIsolated` in actor init

Calls into MainActor synchronously. Risky (must guarantee init runs on main); compiler can't verify the guarantee. Rejected.

### Make the entire wrapper `@MainActor`

```swift
@MainActor public final class AVFoundationCameraController { ... }
```

Forces ALL camera operations (capture, start, stop) onto main actor, blocking UI during long operations. Rejected.

### Use a third-party concurrency library (Combine `@Published`, etc.)

Adds dependency, doesn't actually solve the @MainActor wrap problem. Rejected.

## References

- [ADR 0001 — iOS Native Technology Stack](0001-stack-decision.md) (Swift Concurrency choice)
- [Phase 2 retro](../harness/phase2-retro.md) (where the actor → class pivot was decided)
- [`AVFoundationCameraController` impl](../../packages/AwaIroPlatform/Sources/AwaIroPlatform/Camera/CameraController.swift)
- [Apple — Camera and Media Capture: Thread Safety](https://developer.apple.com/documentation/avfoundation/cameras_and_media_capture)
- [Swift Forums — Sendable and final class @unchecked Sendable](https://forums.swift.org/t/se-0302-sendable-and-final-class-unchecked-sendable/47948)
