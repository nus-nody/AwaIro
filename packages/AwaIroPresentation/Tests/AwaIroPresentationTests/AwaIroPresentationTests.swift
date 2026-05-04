import Testing
@testable import AwaIroPresentation

@Suite("AwaIroPresentation placeholder")
struct AwaIroPresentationTests {
    @Test("module exposes its identifier")
    func moduleIdentifier() {
        #expect(AwaIroPresentation.moduleName == "AwaIroPresentation")
    }
}
