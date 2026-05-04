import Testing
@testable import AwaIroDomain

@Suite("AwaIroDomain placeholder")
struct AwaIroDomainTests {
    @Test("module exposes its identifier")
    func moduleIdentifier() {
        #expect(AwaIroDomain.moduleName == "AwaIroDomain")
    }
}
