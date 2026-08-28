import BackgroundTasks
import Foundation

@MainActor
final class BackgroundTaskCoordinator {
    static let identifier = "online.bejuco.ios.refresh"

    private weak var app: AppModel?
    private var isRegistered = false

    func configure(app: AppModel) {
        self.app = app
    }

    func registerAndSchedule() {
        if !isRegistered {
            isRegistered = BGTaskScheduler.shared.register(forTaskWithIdentifier: Self.identifier, using: nil) { [weak self] task in
                guard let task = task as? BGProcessingTask else {
                    task.setTaskCompleted(success: false)
                    return
                }
                Task { @MainActor [weak self] in
                    guard let self else {
                        task.setTaskCompleted(success: false)
                        return
                    }
                    app?.refreshEarthquakes()
                    app?.gateway.syncPending()
                    task.setTaskCompleted(success: true)
	                    registerAndSchedule()
                }
            }
        }

        let request = BGProcessingTaskRequest(identifier: Self.identifier)
        request.requiresNetworkConnectivity = true
        request.requiresExternalPower = false
        try? BGTaskScheduler.shared.submit(request)
    }
}
