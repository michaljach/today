import ComposableArchitecture
import Foundation

@Reducer
struct NotificationsFeature {
    @ObservableState
    struct State: Equatable {
        var notifications: IdentifiedArrayOf<AppNotification> = []
        var isLoading: Bool = false
        var unreadCount: Int = 0
        var errorMessage: String?
        
        @Presents var destination: Destination.State?
    }
    
    enum Action {
        case onAppear
        case refresh
        case notificationsLoaded(Result<[AppNotification], Error>)
        case unreadCountLoaded(Int)
        case startRealtimeSubscription
        case newNotificationReceived(AppNotification)
        case markAllAsRead
        case markAllAsReadCompleted(Result<Void, Error>)
        case notificationTapped(AppNotification)
        case postLoaded(Result<Post, Error>)
        case destination(PresentationAction<Destination.Action>)
        case delegate(Delegate)
        
        @CasePathable
        enum Delegate {
            case unreadCountChanged(Int)
        }
    }
    
    @Reducer(state: .equatable)
    enum Destination {
        case profile(ProfileFeature)
        case postDetail(PostDetailFeature)
    }
    
    @Dependency(\.notificationClient) var notificationClient
    @Dependency(\.postClient) var postClient
    
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                guard state.notifications.isEmpty else {
                    // Already loaded, just mark as read
                    return .send(.markAllAsRead)
                }
                state.isLoading = true
                state.errorMessage = nil
                
                return .run { send in
                    do {
                        let notifications = try await notificationClient.getNotifications(50, 0)
                        await send(.notificationsLoaded(.success(notifications)))
                    } catch {
                        await send(.notificationsLoaded(.failure(error)))
                    }
                }
                
            case .refresh:
                state.isLoading = true
                state.errorMessage = nil
                
                return .run { send in
                    do {
                        let notifications = try await notificationClient.getNotifications(50, 0)
                        await send(.notificationsLoaded(.success(notifications)))
                    } catch {
                        await send(.notificationsLoaded(.failure(error)))
                    }
                }
                
            case .notificationsLoaded(.success(let notifications)):
                state.isLoading = false
                state.notifications = IdentifiedArrayOf(uniqueElements: notifications)
                // Mark all as read when we load them
                return .send(.markAllAsRead)
                
            case .notificationsLoaded(.failure(let error)):
                state.isLoading = false
                state.errorMessage = error.localizedDescription
                return .none
                
            case .unreadCountLoaded(let count):
                state.unreadCount = count
                return .send(.delegate(.unreadCountChanged(count)))
                
            case .startRealtimeSubscription:
                return .run { send in
                    // First get the initial unread count
                    if let count = try? await notificationClient.getUnreadCount() {
                        await send(.unreadCountLoaded(count))
                    }
                    
                    // Then subscribe to realtime updates
                    for await notification in await notificationClient.subscribeToNotifications() {
                        await send(.newNotificationReceived(notification))
                    }
                }
                
            case .newNotificationReceived(let notification):
                // Insert at the beginning of the list
                state.notifications.insert(notification, at: 0)
                state.unreadCount += 1
                return .send(.delegate(.unreadCountChanged(state.unreadCount)))
                
            case .markAllAsRead:
                let hasUnread = state.notifications.contains { !$0.isRead }
                guard hasUnread || state.unreadCount > 0 else { return .none }
                
                // Optimistically update local state
                for index in state.notifications.indices {
                    state.notifications[index].isRead = true
                }
                state.unreadCount = 0
                
                return .merge(
                    .send(.delegate(.unreadCountChanged(0))),
                    .run { send in
                        do {
                            try await notificationClient.markAllAsRead()
                            await send(.markAllAsReadCompleted(.success(())))
                        } catch {
                            await send(.markAllAsReadCompleted(.failure(error)))
                        }
                    }
                )
                
            case .markAllAsReadCompleted(.success):
                return .none
                
            case .markAllAsReadCompleted(.failure(let error)):
                // Silently fail - the optimistic update stays
                print("Failed to mark notifications as read: \(error)")
                return .none
                
            case .notificationTapped(let notification):
                switch notification.notificationType {
                case .follow:
                    // Navigate to the actor's profile
                    state.destination = .profile(ProfileFeature.State(user: notification.actor, viewingUserId: notification.actorId))
                    return .none
                    
                case .like, .comment:
                    // Navigate to the post - need to fetch it first
                    guard let postId = notification.postId else { return .none }
                    return .run { send in
                        do {
                            let post = try await postClient.getPost(postId)
                            await send(.postLoaded(.success(post)))
                        } catch {
                            await send(.postLoaded(.failure(error)))
                        }
                    }
                }
                
            case .postLoaded(.success(let post)):
                state.destination = .postDetail(PostDetailFeature.State(post: post))
                return .none
                
            case .postLoaded(.failure(let error)):
                state.errorMessage = "Could not load post: \(error.localizedDescription)"
                return .none
                
            case .destination:
                return .none
                
            case .delegate:
                return .none
            }
        }
        .ifLet(\.$destination, action: \.destination)
    }
}
