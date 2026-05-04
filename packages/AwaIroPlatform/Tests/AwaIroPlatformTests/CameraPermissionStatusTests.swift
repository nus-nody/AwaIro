import Testing

@testable import AwaIroPlatform

@Suite("CameraPermissionStatus")
struct CameraPermissionStatusTests {
  @Test("isUsable is true only for .authorized")
  func isUsable() {
    #expect(CameraPermissionStatus.authorized.isUsable)
    #expect(!CameraPermissionStatus.notDetermined.isUsable)
    #expect(!CameraPermissionStatus.denied.isUsable)
    #expect(!CameraPermissionStatus.restricted.isUsable)
  }

  @Test("requiresPrompt is true only for .notDetermined")
  func requiresPrompt() {
    #expect(CameraPermissionStatus.notDetermined.requiresPrompt)
    #expect(!CameraPermissionStatus.authorized.requiresPrompt)
    #expect(!CameraPermissionStatus.denied.requiresPrompt)
    #expect(!CameraPermissionStatus.restricted.requiresPrompt)
  }
}
