import Foundation
import Testing

@testable import AwaIroPlatform

@Suite("FilePathProvider")
struct FilePathProviderTests {
  @Test("databaseURL returns a path under the supplied root")
  func databaseURLUnderRoot() {
    let tmp = FileManager.default.temporaryDirectory
      .appendingPathComponent("awairo-test-\(UUID().uuidString)")
    let provider = FilePathProvider(rootDirectory: tmp)
    let url = provider.databaseURL
    #expect(url.path.hasPrefix(tmp.path))
    #expect(url.lastPathComponent == "awairo.sqlite")
  }

  @Test("databaseURL parent directory exists after access")
  func databaseURLEnsuresDirectory() throws {
    let tmp = FileManager.default.temporaryDirectory
      .appendingPathComponent("awairo-test-\(UUID().uuidString)")
    let provider = FilePathProvider(rootDirectory: tmp)
    _ = provider.databaseURL
    var isDir: ObjCBool = false
    let exists = FileManager.default.fileExists(atPath: tmp.path, isDirectory: &isDir)
    #expect(exists && isDir.boolValue)
  }
}
