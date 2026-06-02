public struct NotificationContent: Sendable, Equatable {
    public let title: String
    public let body: String
    public init(title: String, body: String) {
        self.title = title
        self.body = body
    }
}

public protocol NotificationDispatcher: AnyObject, Sendable {
    func send(_ content: NotificationContent)
}
