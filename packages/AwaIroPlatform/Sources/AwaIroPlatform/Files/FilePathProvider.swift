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
    ensureRootExists()
    return rootDirectory.appendingPathComponent("awairo.sqlite")
  }

  private func ensureRootExists() {
    try? FileManager.default.createDirectory(at: rootDirectory, withIntermediateDirectories: true)
  }
}
