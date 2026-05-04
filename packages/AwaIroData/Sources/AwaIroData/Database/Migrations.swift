import GRDB

public enum Migrations {
  /// Apply all migrations in order. Idempotent.
  public static func applyAll(to writer: any DatabaseWriter) throws {
    var migrator = DatabaseMigrator()
    registerV1(in: &migrator)
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
}
