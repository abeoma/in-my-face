import ServiceManagement
import XCTest

@MainActor
final class LoginItemServiceTests: XCTestCase {
    private final class Backend {
        var status: SMAppService.Status = .notRegistered
        var registrations = 0
        var unregistrations = 0
        var fails = false
        func register() throws {
            registrations += 1
            if fails { throw TestError.failed }
            status = .enabled
        }
        func unregister() throws {
            unregistrations += 1
            if fails { throw TestError.failed }
            status = .notRegistered
        }
    }
    private enum TestError: Error { case failed }

    private func service(_ backend: Backend, isDemo: Bool = false) -> LoginItemService {
        LoginItemService(
            isDemo: isDemo, readStatus: { backend.status },
            register: { try backend.register() }, unregister: { try backend.unregister() })
    }

    func testStartupAndExternalRevocationNeverRegisterAutomatically() {
        let backend = Backend()
        let service = service(backend)
        XCTAssertFalse(service.isRegistered)
        backend.status = .enabled
        service.refresh()
        XCTAssertEqual(service.status, .enabled)
        backend.status = .requiresApproval
        service.refresh()
        XCTAssertEqual(service.status, .requiresApproval)
        XCTAssertEqual(backend.registrations, 0)
        XCTAssertEqual(backend.unregistrations, 0)
    }

    func testExplicitEnableAndDisableUseOSResult() async {
        let backend = Backend()
        let service = service(backend)
        await service.setEnabled(true)
        XCTAssertEqual(service.status, .enabled)
        await service.setEnabled(true)
        XCTAssertEqual(backend.registrations, 1)
        await service.setEnabled(false)
        XCTAssertEqual(service.status, .notRegistered)
        XCTAssertEqual(backend.unregistrations, 1)
        XCTAssertNil(service.errorMessage)
    }

    func testPendingApprovalIsVisibleAndCanBeCancelledWithoutReregistering() async {
        let backend = Backend()
        backend.status = .requiresApproval
        let service = service(backend)
        XCTAssertTrue(service.isRegistered)
        XCTAssertTrue(service.statusText.contains("承認待ち"))
        await service.setEnabled(true)
        XCTAssertEqual(backend.registrations, 0)
        await service.setEnabled(false)
        XCTAssertEqual(backend.unregistrations, 1)
        XCTAssertFalse(service.isRegistered)
    }

    func testRegistrationCanRequireApprovalInsteadOfBeingEnabled() async {
        let backend = Backend()
        let service = LoginItemService(
            readStatus: { backend.status },
            register: { backend.status = .requiresApproval }, unregister: {})
        await service.setEnabled(true)
        XCTAssertEqual(service.status, .requiresApproval)
    }

    func testRegistrationFailureKeepsActualStatusAndCanRetry() async {
        let backend = Backend()
        backend.fails = true
        let service = service(backend)
        await service.setEnabled(true)
        XCTAssertEqual(service.status, .notRegistered)
        XCTAssertNotNil(service.errorMessage)
        XCTAssertFalse(service.isUpdating)
        backend.fails = false
        await service.setEnabled(true)
        XCTAssertEqual(service.status, .enabled)
        XCTAssertNil(service.errorMessage)
    }

    func testUnregistrationFailureKeepsRegistration() async {
        let backend = Backend()
        backend.status = .enabled
        backend.fails = true
        let service = service(backend)
        await service.setEnabled(false)
        XCTAssertEqual(service.status, .enabled)
        XCTAssertNotNil(service.errorMessage)
    }

    func testDemoDoesNotReadOrChangeOSRegistration() async {
        var reads = 0
        let backend = Backend()
        let service = LoginItemService(
            isDemo: true,
            readStatus: {
                reads += 1
                return .enabled
            },
            register: { try backend.register() }, unregister: { try backend.unregister() })
        service.refresh()
        await service.setEnabled(true)
        await service.setEnabled(false)
        XCTAssertEqual(reads, 0)
        XCTAssertEqual(backend.registrations, 0)
        XCTAssertEqual(backend.unregistrations, 0)
        XCTAssertFalse(service.isRegistered)
    }

    func testConcurrentToggleCannotReregisterDuringUnregistration() async {
        let backend = Backend()
        backend.status = .enabled
        var service: LoginItemService?
        let instance = LoginItemService(
            readStatus: { backend.status }, register: { try backend.register() },
            unregister: {
                await service?.setEnabled(true)
                try backend.unregister()
            })
        service = instance
        await instance.setEnabled(false)
        XCTAssertEqual(backend.registrations, 0)
        XCTAssertEqual(backend.unregistrations, 1)
        XCTAssertFalse(instance.isUpdating)
        XCTAssertEqual(instance.status, .notRegistered)
    }

    func testExternalStatusChangeClearsOldErrorButUnchangedStatusKeepsIt() async {
        let backend = Backend()
        backend.fails = true
        let service = service(backend)
        await service.setEnabled(true)
        service.refresh()
        XCTAssertNotNil(service.errorMessage)
        backend.status = .enabled
        service.refresh()
        XCTAssertEqual(service.status, .enabled)
        XCTAssertNil(service.errorMessage)
        XCTAssertEqual(backend.registrations, 1)
    }

    func testThrownRegistrationStillShowsOSApprovalState() async {
        let backend = Backend()
        let service = LoginItemService(
            readStatus: { backend.status },
            register: {
                backend.status = .requiresApproval
                throw TestError.failed
            }, unregister: {})
        await service.setEnabled(true)
        XCTAssertEqual(service.status, .requiresApproval)
        XCTAssertTrue(service.isRegistered)
        XCTAssertNotNil(service.errorMessage)
        XCTAssertFalse(service.isUpdating)
    }

    func testSuspendedUnregistrationBlocksChangesUntilCompletion() async {
        let backend = Backend()
        backend.status = .enabled
        let started = expectation(description: "解除処理が中断された")
        var resumeUnregistration: CheckedContinuation<Void, Never>?
        let service = LoginItemService(
            readStatus: { backend.status }, register: { try backend.register() },
            unregister: {
                // タイムアウト後にTaskが開始した場合は待機を作らない。
                guard !Task.isCancelled else { return }
                await withCheckedContinuation { continuation in
                    resumeUnregistration = continuation
                    started.fulfill()
                }
                try backend.unregister()
            })
        let operation = Task { await service.setEnabled(false) }
        await fulfillment(of: [started], timeout: 2)
        guard let continuation = resumeUnregistration else {
            operation.cancel()
            return
        }
        XCTAssertTrue(service.isUpdating)
        backend.status = .requiresApproval
        service.refresh()
        XCTAssertEqual(service.status, .enabled)
        await service.setEnabled(true)
        XCTAssertEqual(backend.registrations, 0)
        continuation.resume()
        await operation.value
        XCTAssertEqual(backend.unregistrations, 1)
        XCTAssertEqual(service.status, .notRegistered)
        XCTAssertFalse(service.isUpdating)
        await service.setEnabled(true)
        XCTAssertEqual(backend.registrations, 1)
        XCTAssertEqual(service.status, .enabled)
    }

}
