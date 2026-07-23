import IOKit
import IOKit.pwr_mgt
import Testing

@testable import LidwatchCore

@Suite("PowerAssertion")
struct PowerAssertionTests {
    @Test func initialState() {
        let assertion = PowerAssertion(name: "LidwatchTest")
        #expect(!assertion.isActive)
        #expect(assertion.name == "LidwatchTest")
    }

    @Test func defaultType() {
        let assertion = PowerAssertion(name: "Test")
        #expect(
            assertion.type == kIOPMAssertionTypePreventUserIdleSystemSleep as String
        )
    }

    @Test func customType() {
        let assertion = PowerAssertion(name: "Test", type: "CustomType")
        #expect(assertion.type == "CustomType")
    }

    @Test func createAndRelease() {
        var assertion = PowerAssertion(name: "LidwatchTestLifecycle")
        #expect(!assertion.isActive)

        let created = assertion.create()
        #expect(created)
        #expect(assertion.isActive)

        let released = assertion.release()
        #expect(released)
        #expect(!assertion.isActive)
    }

    @Test func doubleCreateIsIdempotent() {
        var assertion = PowerAssertion(name: "LidwatchTestDouble")
        assertion.create()
        let secondCreate = assertion.create()
        #expect(secondCreate)
        #expect(assertion.isActive)
        assertion.release()
    }

    @Test func releaseWithoutCreateIsIdempotent() {
        var assertion = PowerAssertion(name: "LidwatchTestNoCreate")
        let released = assertion.release()
        #expect(released)
        #expect(!assertion.isActive)
    }
}
