import Foundation
import GRDB
import Testing

@testable import AwaIroData

@Suite("Migrations")
struct MigrationsTests {
  @Test("v1 creates photos table with expected columns")
  func v1CreatesPhotosTable() throws {
    let dbQueue = try DatabaseQueue()  // in-memory
    try Migrations.applyAll(to: dbQueue)

    try dbQueue.read { db in
      let columns = try db.columns(in: "photos")
      let names = columns.map(\.name).sorted()
      #expect(names == ["developed_at", "file_url", "id", "memo", "taken_at"])
    }
  }

  @Test("applyAll is idempotent")
  func idempotent() throws {
    let dbQueue = try DatabaseQueue()
    try Migrations.applyAll(to: dbQueue)
    try Migrations.applyAll(to: dbQueue)  // second call shouldn't error
    try dbQueue.read { db in
      let exists = try db.tableExists("photos")
      #expect(exists)
    }
  }

  @Test("v2 adds developed_at column with backfill (taken_at + 86400)")
  func v2AddsDevelopedAt() throws {
    let queue = try DatabaseQueue()  // in-memory

    // Manually apply v1 only (raw SQL, not using applyAll which would also run v2).
    try queue.write { db in
      try db.execute(
        sql: """
          CREATE TABLE photos (
            id TEXT PRIMARY KEY,
            taken_at REAL NOT NULL,
            file_url TEXT NOT NULL,
            memo TEXT
          );
          """)
      try db.execute(
        sql: """
          INSERT INTO photos (id, taken_at, file_url, memo)
          VALUES ('11111111-1111-1111-1111-111111111111', 1730000000, '/tmp/x.jpg', 'm')
          """)
    }

    // Apply v2 only (test helper).
    try Migrations.applyV2Only(to: queue)

    // Verify the column exists and is backfilled.
    try queue.read { db in
      let row = try Row.fetchOne(
        db,
        sql: """
          SELECT taken_at, developed_at FROM photos
          WHERE id = '11111111-1111-1111-1111-111111111111'
          """)!
      let taken: Double = row["taken_at"]
      let developed: Double = row["developed_at"]
      #expect(developed == taken + 86400)
    }
  }
}
