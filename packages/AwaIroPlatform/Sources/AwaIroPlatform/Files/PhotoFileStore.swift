import Foundation

public struct PhotoFileStore: Sendable {
  private let filePathProvider: FilePathProvider

  public init(filePathProvider: FilePathProvider) {
    self.filePathProvider = filePathProvider
  }

  /// Writes JPEG data for a photo to disk and returns the file URL.
  /// File name format: <uuid>.jpg under FilePathProvider.photoDirectory.
  public func write(data: Data, photoId: UUID) throws -> URL {
    let url = filePathProvider.photoDirectory
      .appendingPathComponent("\(photoId.uuidString).jpg")
    try data.write(to: url, options: .atomic)
    return url
  }

  /// Removes a previously-written photo file. Idempotent: missing file is not an error.
  public func delete(at url: URL) throws {
    if FileManager.default.fileExists(atPath: url.path) {
      try FileManager.default.removeItem(at: url)
    }
  }
}
