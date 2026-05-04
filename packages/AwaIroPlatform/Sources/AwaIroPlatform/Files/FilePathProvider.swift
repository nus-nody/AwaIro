import Foundation

public struct FilePathProvider: Sendable {
  private let rootDirectory: URL

  public init(rootDirectory: URL) {
    self.rootDirectory = rootDirectory
  }

  /// Production convenience: rooted at the app's Application Support directory.
  public static func defaultProduction() throws -> FilePathProvider {
    let appSupport = try FileManager.default.url(
      for: .applicationSupportDirectory,
      in: .userDomainMask,
      appropriateFor: nil,
      create: true
    ).appendingPathComponent("AwaIro", isDirectory: true)
    return FilePathProvider(rootDirectory: appSupport)
  }

  public var databaseURL: URL {
    ensureDirectory(rootDirectory)
    return rootDirectory.appendingPathComponent("awairo.sqlite")
  }

  public var photoDirectory: URL {
    let dir = rootDirectory.appendingPathComponent("photos", isDirectory: true)
    ensureDirectory(dir)
    return dir
  }

  private func ensureDirectory(_ url: URL) {
    try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
  }
}
