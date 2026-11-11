import XCTest
@testable import NotchFlow

private final class MockProvider: LicenseProvider, @unchecked Sendable {
    var activateResult: Result<ProviderLicense, LicenseProviderError> =
        .success(ProviderLicense(status: .active, instanceID: "inst-1", activationLimit: 2, activationUsage: 1))
    var validateResult: Result<ProviderLicense, LicenseProviderError> =
        .success(ProviderLicense(status: .active, instanceID: "inst-1", activationLimit: 2, activationUsage: 1))
    var activatedKeys: [String] = []
    var deactivated: [String] = []
    var validateCalls = 0

    func activate(key: String, instanceName: String) async throws -> ProviderLicense {
        activatedKeys.append(key)
        return try activateResult.get()
    }

    func validate(key: String, instanceID: String) async throws -> ProviderLicense {
        validateCalls += 1
        return try validateResult.get()
    }

    func deactivate(key: String, instanceID: String) async throws {
        deactivated.append(instanceID)
    }
}

@MainActor
final class OnlineLicenseTests: XCTestCase {
    private var clock = Date(timeIntervalSince1970: 1_800_000_000)
    private var defaults: UserDefaults!
    private var suite = ""

    override func setUp() {
        suite = "NotchFlowTests.online.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suite)
    }

    private func makeStore(_ provider: MockProvider, storage: LicenseSecureStorage = InMemoryLicenseStorage()) -> LicenseStore {
        LicenseStore(defaults: defaults, storage: storage, provider: provider, now: { [unowned self] in self.clock })
    }

    func testActivateNormalizesKeyAndGrantsPro() async throws {
        let provider = MockProvider()
        let store = makeStore(provider)
        XCTAssertFalse(store.hasPro)
        try await store.activateOnline("  nfpro-abcd\n-efgh ")
        XCTAssertEqual(provider.activatedKeys, ["NFPRO-ABCD-EFGH"])
        XCTAssertTrue(store.hasPro)
        XCTAssertTrue(store.hasPaidPro)
        XCTAssertEqual(store.online?.instanceID, "inst-1")
    }

    func testLimitReachedLeavesFree() async {
        let provider = MockProvider()
        provider.activateResult = .failure(.limitReached)
        let store = makeStore(provider)
        do {
            try await store.activateOnline("KEY")
            XCTFail("expected limit error")
        } catch {
            XCTAssertEqual(error as? LicenseProviderError, .limitReached)
        }
        XCTAssertFalse(store.hasPro)
    }

    func testRecordSurvivesRelaunch() async throws {
        let storage = InMemoryLicenseStorage()
        try await makeStore(MockProvider(), storage: storage).activateOnline("KEY")
        XCTAssertTrue(makeStore(MockProvider(), storage: storage).hasPro)
    }

    func testRevalidatesWeeklyAndDropsRefundedKey() async throws {
        let provider = MockProvider()
        let store = makeStore(provider)
        try await store.activateOnline("KEY")
        await store.revalidateIfNeeded()
        XCTAssertEqual(provider.validateCalls, 0, "not due yet")
        clock += LicenseStore.revalidateInterval + 1
        provider.validateResult = .success(ProviderLicense(status: .disabled, instanceID: nil, activationLimit: 2, activationUsage: 1))
        await store.revalidateIfNeeded()
        XCTAssertEqual(provider.validateCalls, 1)
        XCTAssertFalse(store.hasPro)
    }

    func testOfflineGraceThenFree() async throws {
        let provider = MockProvider()
        let store = makeStore(provider)
        try await store.activateOnline("KEY")
        provider.validateResult = .failure(.network)
        clock += LicenseStore.revalidateInterval + 1
        await store.revalidateIfNeeded()
        XCTAssertTrue(store.hasPro, "network failure keeps Pro during grace")
        clock += LicenseStore.offlineGrace
        XCTAssertFalse(store.hasPro, "grace ran out")
    }

    func testDeactivateFreesSeat() async throws {
        let provider = MockProvider()
        let store = makeStore(provider)
        try await store.activateOnline("KEY")
        try await store.deactivateOnline()
        XCTAssertEqual(provider.deactivated, ["inst-1"])
        XCTAssertNil(store.online)
        XCTAssertFalse(store.hasPro)
    }

    func testTrialRunsFourteenDaysOnce() {
        let store = makeStore(MockProvider())
        XCTAssertTrue(store.canStartTrial)
        store.startTrial()
        XCTAssertTrue(store.hasPro)
        XCTAssertFalse(store.hasPaidPro)
        XCTAssertEqual(store.trialDaysLeft, 14)
        XCTAssertFalse(store.canStartTrial)
        clock += LicenseStore.trialLength
        XCTAssertFalse(store.hasPro)
        XCTAssertFalse(store.canStartTrial)
    }

    func testActivationLinkParsing() {
        XCTAssertEqual(LicenseStore.activationKey(from: URL(string: "notchflow://activate?key=ABC-123")!), "ABC-123")
        XCTAssertNil(LicenseStore.activationKey(from: URL(string: "notchflow://other?key=ABC")!))
        XCTAssertNil(LicenseStore.activationKey(from: URL(string: "https://activate?key=ABC")!))
    }

    func testLemonSqueezyErrorMapping() {
        typealias R = LemonSqueezyLicenseProvider.Response
        func response(_ error: String) -> R {
            R(activated: false, valid: nil, deactivated: nil, error: error, license_key: nil, instance: nil, meta: nil)
        }
        XCTAssertEqual(LemonSqueezyLicenseProvider.error(for: response("This license key has reached the activation limit.")), .limitReached)
        XCTAssertEqual(LemonSqueezyLicenseProvider.error(for: response("license_key not found.")), .invalidKey)
    }
}
