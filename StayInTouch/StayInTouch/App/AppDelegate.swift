//
//  AppDelegate.swift
//  StayInTouch
//
//  Created by Codex on 2/2/26.
//

import UIKit
import UserNotifications
import BackgroundTasks

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        ContactsChangeObserver.shared.start()
        NotificationScheduler.shared.startObserving()
        UNUserNotificationCenter.current().delegate = self
        registerBackgroundTasks()
        Task { await NotificationScheduler.shared.scheduleAll() }
        return true
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        NotificationCenter.default.post(name: .notificationDeepLink, object: nil, userInfo: userInfo)
        completionHandler()
    }

    private func registerBackgroundTasks() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: BackgroundTaskIdentifier.refresh, using: nil) { task in
            guard let refreshTask = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }
            self.handleAppRefresh(task: refreshTask)
        }
        scheduleAppRefresh()
    }

    private func handleAppRefresh(task: BGAppRefreshTask) {
        scheduleAppRefresh()

        let operation = Task {
            await NotificationScheduler.shared.scheduleAll()
            task.setTaskCompleted(success: true)
        }

        task.expirationHandler = {
            operation.cancel()
            task.setTaskCompleted(success: false)
        }
    }

    private func scheduleAppRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: BackgroundTaskIdentifier.refresh)
        request.earliestBeginDate = Calendar.current.date(byAdding: .hour, value: 6, to: Date())
        try? BGTaskScheduler.shared.submit(request)
    }
}

enum BackgroundTaskIdentifier {
    static let refresh = "com.slavins.stayintouch.refresh"
}
