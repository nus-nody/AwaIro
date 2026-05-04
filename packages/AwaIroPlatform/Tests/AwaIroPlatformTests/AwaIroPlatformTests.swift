import Testing
@testable import AwaIroPlatform

@Suite("AwaIroPlatform placeholder")
struct AwaIroPlatformTests {
    @Test("module exposes its identifier")
    func moduleIdentifier() {
        #expect(AwaIroPlatform.moduleName == "AwaIroPlatform")
    }
}
