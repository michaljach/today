import ComposableArchitecture
import Foundation

@Reducer
struct NotificationsFeature {
    @ObservableState
    struct State: Equatable {
        var notifications: [NotificationItem] = []
        var isLoading: Bool = false
    }
    
    enum Action {
        case onAppear
        case notificationsLoaded([NotificationItem])
    }
    
    @Dependency(\.continuousClock) var clock
    
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                guard state.notifications.isEmpty else { return .none }
                state.isLoading = true
                return .run { send in
                    try await clock.sleep(for: .milliseconds(500))
                    await send(.notificationsLoaded(NotificationItem.mockNotifications))
                }
                
            case .notificationsLoaded(let notifications):
                state.isLoading = false
                state.notifications = notifications
                return .none
            }
        }
    }
}

struct NotificationItem: Equatable, Identifiable {
    let id: UUID
    let user: User
    let type: NotificationType
    let createdAt: Date
    
    enum NotificationType: Equatable {
        case like
        case comment
        case follow
    }
    
    init(
        id: UUID = UUID(),
        user: User,
        type: NotificationType,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.user = user
        self.type = type
        self.createdAt = createdAt
    }
}

extension NotificationItem {
    static let mockNotifications: [NotificationItem] = [
        NotificationItem(user: .mock1, type: .like, createdAt: Date().addingTimeInterval(-300)),
        NotificationItem(user: .mock2, type: .follow, createdAt: Date().addingTimeInterval(-3600)),
        NotificationItem(user: .mock3, type: .comment, createdAt: Date().addingTimeInterval(-7200)),
        NotificationItem(user: .mock4, type: .like, createdAt: Date().addingTimeInterval(-86400)),
    ]
}
