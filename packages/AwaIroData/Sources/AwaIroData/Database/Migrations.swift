import GRDB

public enum Migrations {
  /// Apply all migrations in order. Idempotent.
  public static func applyAll(to writer: any DatabaseWriter) throws {
    var migrator = DatabaseMigrator()
    registerV1(in: &migrator)
    registerV2(in: &migrator)
    try migrator.migrate(writer)
  }

  /// Test-only helper: apply only v2 (assumes v1 schema exists, e.g. seeded by raw SQL).
  public static func applyV2Only(to writer: any DatabaseWriter) throws {
    var migrator = DatabaseMigrator()
    // Mark v1 as already applied so the migrator skips it.
    migrator.registerMigration("v1_create_photos") { _ in
      // already applied externally
    }
    registerV2(in: &migrator)
    try migrator.migrate(writer)
  }

  private static func registerV1(in migrator: inout DatabaseMigrator) {
    migrator.registerMigration("v1_create_photos") { db in
      try db.create(table: "photos") { t in
        t.column("id", .text).primaryKey()
        t.column("taken_at", .double).notNull().indexed()
        t.column("file_url", .text).notNull()
        t.column("memo", .text)
      }
    }
  }

  private static func registerV2(in migrator: inout DatabaseMigrator) {
    migrator.registerMigration("v2_add_developed_at") { db in
      // Add nullable column first to allow backfill.
      try db.alter(table: "photos") { t in
        t.add(column: "developed_at", .double)
      }
      // Backfill: developed_at = taken_at + 86400 (24h).
      try db.execute(
        sql: "UPDATE photos SET developed_at = taken_at + 86400 WHERE developed_at IS NULL")
      // SQLite cannot ALTER COLUMN ... NOT NULL after the fact; the column stays nullable.
      // The application layer (PhotoRepositoryImpl.insert) is expected to always supply it.
    }
  }
}
