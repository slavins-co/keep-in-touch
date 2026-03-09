//
//  AppDelegate.swift
//  KeepInTouch
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
        AnalyticsService.initialize()
        AnalyticsService.track("app.launched")
        ContactsChangeObserver.shared.start()
        NotificationScheduler.shared.startObserving()
        UNUserNotificationCenter.current().delegate = self
        registerBackgroundTasks()
        Task { await NotificationScheduler.shared.scheduleAll() }
        return true
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        AnalyticsService.track("app.foregrounded")
        Task { await NotificationScheduler.shared.scheduleAll() }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        AnalyticsService.track("notification.tapped")
        let userInfo = response.notification.request.content.userInfo

        if response.actionIdentifier == NotificationIdentifier.actionLogConnection,
           let personIdString = userInfo["personId"] as? String,
           let personId = UUID(uuidString: personIdString) {
            logConnectionFromNotification(personId: personId)
            completionHandler()
            return
        }

        // Only forward known fields to prevent untrusted data propagation
        let sanitized: [AnyHashable: Any] = [
            "type": userInfo["type"] as? String ?? "",
            "personId": userInfo["personId"] as? String ?? "",
            "category": userInfo["category"] as? String ?? ""
        ]
        DeepLinkRouter.shared.handleNotification(userInfo: sanitized)
        completionHandler()
    }

    private func logConnectionFromNotification(personId: UUID) {
        // Use background context — notification handlers may run off main thread
        let context = CoreDataStack.shared.newBackgroundContext()
        let personRepo = CoreDataPersonRepository(context: context)
        let touchRepo = CoreDataTouchEventRepository(context: context)

        guard var person = personRepo.fetch(id: personId) else { return }

        let now = Date()
        let touch = TouchEvent(
            id: UUID(),
            personId: personId,
            at: now,
            method: .other,
            notes: "Logged from notification",
            timeOfDay: nil,
            createdAt: now,
            modifiedAt: now
        )

        do {
            try touchRepo.save(touch)
            person.lastTouchAt = now
            person.lastTouchMethod = .other
            person.lastTouchNotes = "Logged from notification"
            person.snoozedUntil = nil
            person.modifiedAt = now
            try personRepo.save(person)
            Task { @MainActor in
                NotificationCenter.default.post(name: .personDidChange, object: personId)
            }
        } catch {
            AppLogger.logError(error, category: AppLogger.notifications, context: "AppDelegate.logConnectionFromNotification")
        }
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
    static let refresh = "com.slavins.keepintouch.refresh"
}
