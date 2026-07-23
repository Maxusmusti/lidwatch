import Testing

@testable import LidwatchCore

@Suite("SystemInfo")
struct SystemInfoTests {
    @Test func architectureDetection() {
        let info = SystemInfo()
        #if arch(arm64)
        #expect(info.isAppleSilicon)
        #expect(info.chipArchitecture == "Apple Silicon (arm64)")
        #else
        #expect(!info.isAppleSilicon)
        #expect(info.chipArchitecture == "Intel (x86_64)")
        #endif
    }

    @Test func powerSourceDetection() {
        let info = SystemInfo()
        _ = info.isOnACPower
    }

    @Test func externalDisplayCount() {
        let info = SystemInfo()
        #expect(info.externalDisplayCount >= 0)
    }

    @Test func hasExternalDisplayConsistency() {
        let info = SystemInfo()
        if info.externalDisplayCount > 0 {
            #expect(info.hasExternalDisplay)
        } else {
            #expect(!info.hasExternalDisplay)
        }
    }
}
