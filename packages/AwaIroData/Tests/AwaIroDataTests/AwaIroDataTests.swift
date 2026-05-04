import Testing
@testable import AwaIroData

@Suite("AwaIroData placeholder")
struct AwaIroDataTests {
    @Test("module exposes its identifier")
    func moduleIdentifier() {
        #expect(AwaIroData.moduleName == "AwaIroData")
    }
}
