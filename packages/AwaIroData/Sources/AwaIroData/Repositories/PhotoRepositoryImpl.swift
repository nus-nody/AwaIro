import AwaIroDomain
import Foundation
import GRDB

public final class PhotoRepositoryImpl: PhotoRepository, @unchecked Sendable {
  private let writer: any DatabaseWriter

  public init(writer: any DatabaseWriter) {
    self.writer = writer
  }

  public func todayPhoto(now: Date) async throws -> Photo? {
    let cal = Calendar.current
    let startOfDay = cal.startOfDay(for: now)
    let endOfDay = cal.date(byAdding: .day, value: 1, to: startOfDay)!

    return try await writer.read { db in
      let row = try Row.fetchOne(
        db,
        sql: """
              SELECT id, taken_at, file_url, memo
              FROM photos
              WHERE taken_at >= ? AND taken_at < ?
              ORDER BY taken_at DESC
              LIMIT 1
          """,
        arguments: [startOfDay.timeIntervalSince1970, endOfDay.timeIntervalSince1970]
      )
      return row.map(Photo.init(row:))
    }
  }

  public func insert(_ photo: Photo) async throws {
    try await writer.write { db in
      try db.execute(
        sql: """
              INSERT INTO photos (id, taken_at, file_url, memo)
              VALUES (?, ?, ?, ?)
          """,
        arguments: [
          photo.id.uuidString,
          photo.takenAt.timeIntervalSince1970,
          photo.fileURL.absoluteString,
          photo.memo,
        ]
      )
    }
  }
}

extension Photo {
  fileprivate init(row: Row) {
    self.init(
      id: UUID(uuidString: row["id"])!,
      takenAt: Date(timeIntervalSince1970: row["taken_at"]),
      fileURL: URL(string: row["file_url"])!,
      memo: row["memo"]
    )
  }
}
