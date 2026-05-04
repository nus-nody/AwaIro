import Foundation
import Testing

@testable import AwaIroPlatform

@Suite("PhotoFileStore")
struct PhotoFileStoreTests {

  private func makeStore() throws -> (PhotoFileStore, FilePathProvider) {
    let tmp = FileManager.default.temporaryDirectory
      .appendingPathComponent("awairo-photo-test-\(UUID().uuidString)")
    let provider = FilePathProvider(rootDirectory: tmp)
    return (PhotoFileStore(filePathProvider: provider), provider)
  }

  @Test("write returns a URL under photoDirectory and the file is readable")
  func writeRoundTrip() throws {
    let (store, provider) = try makeStore()
    let data = Data([0xFF, 0xD8, 0xFF, 0xE0])
    let id = UUID()
    let url = try store.write(data: data, photoId: id)
    #expect(url.path.hasPrefix(provider.photoDirectory.path))
    #expect(url.lastPathComponent.hasPrefix(id.uuidString))
    let read = try Data(contentsOf: url)
    #expect(read == data)
  }

  @Test("write produces .jpg extension")
  func extensionIsJpg() throws {
    let (store, _) = try makeStore()
    let url = try store.write(data: Data([0xFF, 0xD8]), photoId: UUID())
    #expect(url.pathExtension == "jpg")
  }

  @Test("delete removes the file")
  func deleteRemoves() throws {
    let (store, _) = try makeStore()
    let url = try store.write(data: Data([0xFF, 0xD8]), photoId: UUID())
    #expect(FileManager.default.fileExists(atPath: url.path))
    try store.delete(at: url)
    #expect(!FileManager.default.fileExists(atPath: url.path))
  }

  @Test("delete on missing file does not throw (idempotent)")
  func deleteIdempotent() throws {
    let (store, provider) = try makeStore()
    let bogus = provider.photoDirectory.appendingPathComponent("nonexistent.jpg")
    try store.delete(at: bogus)
  }
}
