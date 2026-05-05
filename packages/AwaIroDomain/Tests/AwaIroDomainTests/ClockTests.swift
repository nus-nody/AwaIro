import Foundation
import Testing

@testable import AwaIroDomain

@Suite("Clock")
struct ClockTests {
  @Test("SystemClock returns Date close to Date()")
  func systemClockNow() {
    let clock = SystemClock()
    let before = Date()
    let now = clock.now()
    let after = Date()
    #expect(now >= before && now <= after)
  }

  @Test("FixedClock returns the configured instant repeatedly")
  func fixedClockIsConstant() {
    let fixed = Date(timeIntervalSince1970: 1_730_000_000)
    let clock = FixedClock(instant: fixed)
    #expect(clock.now() == fixed)
    #expect(clock.now() == fixed)
  }
}
