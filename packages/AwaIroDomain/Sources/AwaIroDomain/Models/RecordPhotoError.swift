import Foundation

public enum RecordPhotoError: Error, Equatable, Sendable {
  /// G1 guardrail: a photo was already recorded today (device-local calendar day).
  case alreadyRecordedToday

  /// Repository write failed (forwarded from Data layer).
  case repositoryFailure(message: String)
}
