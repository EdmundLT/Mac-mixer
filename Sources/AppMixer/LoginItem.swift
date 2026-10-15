import Combine
import ServiceManagement

@MainActor
final class LoginItemModel: ObservableObject {
    @Published private(set) var status: SMAppService.Status = .notRegistered
    @Published private(set) var errorMessage: String?

    private let readStatus: () -> SMAppService.Status
    private let register: () throws -> Void
    private let unregister: () throws -> Void

    var isRequested: Bool { status == .enabled || status == .requiresApproval }

    init(
        readStatus: @escaping () -> SMAppService.Status = { SMAppService.mainApp.status },
        register: @escaping () throws -> Void = { try SMAppService.mainApp.register() },
        unregister: @escaping () throws -> Void = { try SMAppService.mainApp.unregister() }
    ) {
        self.readStatus = readStatus
        self.register = register
        self.unregister = unregister
        refresh()
    }

    func refresh() { status = readStatus() }

    func setEnabled(_ enabled: Bool) {
        errorMessage = nil
        do {
            if enabled { try register() } else { try unregister() }
        } catch {
            errorMessage = "Could not update login item: \(error.localizedDescription)"
        }
        // The OS is the source of truth, including denied or pending approval.
        refresh()
    }

    func openSettings() { SMAppService.openSystemSettingsLoginItems() }
}
