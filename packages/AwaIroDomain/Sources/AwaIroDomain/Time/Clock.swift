import Foundation

/// A pluggable source of the current instant.
/// Inject via UseCase init to keep time-dependent logic deterministic in tests.
public protocol Clock: Sendable {
  func now() -> Date
}

/// Production clock — returns `Date()`.
public struct SystemClock: Clock {
  public init() {}
  public func now() -> Date { Date() }
}

/// Test double — returns the same instant every call.
public struct FixedClock: Clock {
  private let instant: Date
  public init(instant: Date) { self.instant = instant }
  public func now() -> Date { instant }
}
