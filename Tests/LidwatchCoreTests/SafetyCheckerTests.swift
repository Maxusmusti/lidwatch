import Testing

@testable import LidwatchCore

struct MockSystemChecker: SystemChecking {
    var isAppleSilicon: Bool = true
    var isOnACPower: Bool = true
    var hasExternalDisplay: Bool = true
    var hasExternalKeyboard: Bool = true
    var hasExternalMouse: Bool = true
    var batteryLevel: Int = 100
}

@Suite("SafetyChecker")
struct SafetyCheckerTests {
    @Test func allGreenAppleSilicon() {
        let mock = MockSystemChecker()
        let checker = SafetyChecker(checker: mock)
        let report = checker.checkClamshellReadiness()

        #expect(report.readiness == .ready)
        #expect(report.isAppleSilicon)
        #expect(report.checks.count == 5)
    }

    @Test func noPowerAppleSilicon() {
        var mock = MockSystemChecker()
        mock.isOnACPower = false
        let checker = SafetyChecker(checker: mock)
        let report = checker.checkClamshellReadiness()

        #expect(report.readiness == .partial)
        let powerCheck = report.checks.first { $0.name == "AC Power" }
        #expect(powerCheck != nil)
        #expect(powerCheck?.passed == false)
    }

    @Test func noDisplayAppleSilicon() {
        var mock = MockSystemChecker()
        mock.hasExternalDisplay = false
        let checker = SafetyChecker(checker: mock)
        let report = checker.checkClamshellReadiness()

        #expect(report.readiness == .partial)
    }

    @Test func noPowerNoDisplayAppleSilicon() {
        var mock = MockSystemChecker()
        mock.isOnACPower = false
        mock.hasExternalDisplay = false
        let checker = SafetyChecker(checker: mock)
        let report = checker.checkClamshellReadiness()

        #expect(report.readiness == .notReady)
    }

    @Test func intelWithPowerIsReady() {
        var mock = MockSystemChecker()
        mock.isAppleSilicon = false
        mock.hasExternalDisplay = false
        let checker = SafetyChecker(checker: mock)
        let report = checker.checkClamshellReadiness()

        #expect(report.readiness == .ready)
        #expect(!report.isAppleSilicon)
    }

    @Test func intelWithoutPowerIsPartial() {
        var mock = MockSystemChecker()
        mock.isAppleSilicon = false
        mock.isOnACPower = false
        let checker = SafetyChecker(checker: mock)
        let report = checker.checkClamshellReadiness()

        #expect(report.readiness == .partial)
    }

    @Test func checkDescriptions() {
        let passing = ClamshellCheck(name: "Test", passed: true, detail: "OK")
        #expect(passing.description.contains("✓"))

        let failing = ClamshellCheck(name: "Test", passed: false, detail: "Missing")
        #expect(failing.description.contains("✗"))
    }

    @Test func readinessLevelDescriptions() {
        #expect(ReadinessLevel.ready.description.contains("Safe"))
        #expect(ReadinessLevel.partial.description.contains("Missing"))
        #expect(ReadinessLevel.notReady.description.contains("Keep lid open"))
    }

    @Test func missingKeyboardDoesNotBlockReadiness() {
        var mock = MockSystemChecker()
        mock.hasExternalKeyboard = false
        mock.hasExternalMouse = false
        let checker = SafetyChecker(checker: mock)
        let report = checker.checkClamshellReadiness()

        #expect(report.readiness == .ready)
    }
}
