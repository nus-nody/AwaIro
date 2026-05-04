import Foundation
import GRDB

public enum DatabaseFactory {
  /// Production: file-backed DatabasePool at the given URL.
  /// Migrations are applied automatically on creation.
  public static func makePool(at url: URL) throws -> DatabasePool {
    let pool = try DatabasePool(path: url.path)
    try Migrations.applyAll(to: pool)
    return pool
  }

  /// Tests: in-memory DatabaseQueue. Migrations applied.
  public static func makeInMemoryQueue() throws -> DatabaseQueue {
    let queue = try DatabaseQueue()
    try Migrations.applyAll(to: queue)
    return queue
  }
}
