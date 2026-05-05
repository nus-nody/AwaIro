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
              SELECT id, taken_at, developed_at, file_url, memo
              FROM photos
              WHERE taken_at >= ? AND taken_at < ?
              ORDER BY taken_at DESC
              LIMIT 1
          """,
        arguments: [startOfDay.timeIntervalSince1970, endOfDay.timeIntervalSince1970]
      )
      return try row.map { try Photo(row: $0) }
    }
  }

  public func insert(_ photo: Photo) async throws {
    try await writer.write { db in
      try db.execute(
        sql: """
              INSERT INTO photos (id, taken_at, developed_at, file_url, memo)
              VALUES (?, ?, ?, ?, ?)
          """,
        arguments: [
          photo.id.uuidString,
          photo.takenAt.timeIntervalSince1970,
          photo.developedAt.timeIntervalSince1970,
          photo.fileURL.absoluteString,
          photo.memo,
        ]
      )
    }
  }

  public func findAllOrderByTakenAtDesc() async throws -> [Photo] {
    try await writer.read { db in
      try Row.fetchAll(
        db,
        sql: """
              SELECT id, taken_at, developed_at, file_url, memo
              FROM photos
              ORDER BY taken_at DESC
          """
      ).map { try Photo(row: $0) }
    }
  }

  public func findById(_ id: UUID) async throws -> Photo? {
    try await writer.read { db in
      let row = try Row.fetchOne(
        db,
        sql: """
              SELECT id, taken_at, developed_at, file_url, memo
              FROM photos
              WHERE id = ?
              LIMIT 1
          """,
        arguments: [id.uuidString]
      )
      return try row.map { try Photo(row: $0) }
    }
  }

  public func updateMemo(id: UUID, memo: String?) async throws {
    try await writer.write { db in
      try db.execute(
        sql: "UPDATE photos SET memo = ? WHERE id = ?",
        arguments: [memo, id.uuidString]
      )
    }
  }
}

extension Photo {
  fileprivate init(row: Row) throws {
    guard let developedAtRaw: Double = row["developed_at"] else {
      throw DatabaseError(
        message: "developed_at is NULL for photo id=\(row["id"] as String? ?? "?")")
    }
    self.init(
      id: UUID(uuidString: row["id"])!,
      takenAt: Date(timeIntervalSince1970: row["taken_at"]),
      developedAt: Date(timeIntervalSince1970: developedAtRaw),
      fileURL: URL(string: row["file_url"])!,
      memo: row["memo"]
    )
  }
}
