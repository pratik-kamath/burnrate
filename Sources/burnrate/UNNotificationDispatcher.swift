import Foundation
import UserNotifications
import BurnrateCore

final class UNNotificationDispatcher: NotificationDispatcher, @unchecked Sendable {
    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func send(_ content: NotificationContent) {
        let c = UNMutableNotificationContent()
        c.title = content.title
        c.body = content.body
        let req = UNNotificationRequest(identifier: UUID().uuidString, content: c, trigger: nil)
        UNUserNotificationCenter.current().add(req)
    }
}
