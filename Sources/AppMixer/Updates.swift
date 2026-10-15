import AppKit
import Combine
import Sparkle

@MainActor
final class UpdateModel: NSObject, ObservableObject, SPUUpdaterDelegate {
    @Published private(set) var canCheck = false
    @Published private(set) var automaticallyChecks = false
    @Published private(set) var errorMessage: String?
    private var controller: SPUStandardUpdaterController?
    var inspectionFinished: ((Error?) -> Void)?
    var beforeInstall: () -> Void = {}

    func start() {
        guard controller == nil else { return }
        let controller = SPUStandardUpdaterController(startingUpdater: false, updaterDelegate: self, userDriverDelegate: nil)
        self.controller = controller
        controller.updater.publisher(for: \.canCheckForUpdates)
            .assign(to: &$canCheck)
        controller.updater.publisher(for: \.automaticallyChecksForUpdates)
            .assign(to: &$automaticallyChecks)
        do { try controller.updater.start() }
        catch { errorMessage = "Updates unavailable: \(error.localizedDescription)" }
    }

    func setAutomaticChecks(_ enabled: Bool) {
        controller?.updater.automaticallyChecksForUpdates = enabled
    }

    func inspectFeed() { controller?.updater.checkForUpdateInformation() }

    func updater(_ updater: SPUUpdater, didFinishUpdateCycleFor updateCheck: SPUUpdateCheck, error: Error?) {
        // SUNoUpdateError is the expected result for an empty bootstrap feed.
        let nsError = error as NSError?
        let noUpdate = nsError?.domain == SUSparkleErrorDomain && nsError?.code == Int(SUError.noUpdateError.rawValue)
        let failure = noUpdate ? nil : error
        inspectionFinished?(failure)
    }

    func check() {
        guard canCheck else { return }
        NSApp.activate(ignoringOtherApps: true)
        controller?.checkForUpdates(nil)
    }

    func updater(_ updater: SPUUpdater, willInstallUpdate item: SUAppcastItem) {
        beforeInstall()
    }
}
