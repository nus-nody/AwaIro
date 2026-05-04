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
      #expect(names == ["file_url", "id", "memo", "taken_at"])
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
}
