import ComposableArchitecture
import SwiftUI

struct NotificationsView: View {
    @Bindable var store: StoreOf<NotificationsFeature>
    
    var body: some View {
        NavigationStack {
            Group {
                if store.isLoading && store.notifications.isEmpty {
                    ProgressView("Loading...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let errorMessage = store.errorMessage, store.notifications.isEmpty {
                    ContentUnavailableView {
                        Label("Error", systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(errorMessage)
                    } actions: {
                        Button("Retry") {
                            store.send(.refresh)
                        }
                    }
                } else if store.notifications.isEmpty {
                    emptyState
                } else {
                    List(store.notifications) { notification in
                        Button {
                            store.send(.notificationTapped(notification))
                        } label: {
                            NotificationRow(notification: notification)
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(notification.isRead ? Color.clear : Color.blue.opacity(0.05))
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    }
                    .listStyle(.plain)
                    .refreshable {
                        await store.send(.refresh).finish()
                    }
                }
            }
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(item: $store.scope(state: \.destination?.profile, action: \.destination.profile)) { profileStore in
                ProfileView(store: profileStore)
            }
            .navigationDestination(item: $store.scope(state: \.destination?.postDetail, action: \.destination.postDetail)) { postDetailStore in
                PostDetailView(store: postDetailStore)
            }
        }
        .onAppear {
            store.send(.onAppear)
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "bell.slash")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            
            Text("No notifications yet")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            Text("When you get notifications, they'll show up here")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct NotificationRow: View {
    let notification: AppNotification
    
    var body: some View {
        HStack(spacing: 12) {
            // Unread indicator
            Circle()
                .fill(notification.isRead ? Color.clear : Color.blue)
                .frame(width: 8, height: 8)
            
            // Avatar
            if let actor = notification.actor {
                AvatarView(url: actor.avatarURL, size: 44)
            } else {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 44, height: 44)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(notificationText)
                    .font(.subheadline)
                
                Text(notification.createdAt.timeAgoDisplay())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            notificationIcon
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
    
    private var notificationText: AttributedString {
        let displayName = notification.actor?.displayName ?? "Someone"
        var string = AttributedString(displayName)
        string.font = .subheadline.bold()
        
        var action: AttributedString
        switch notification.notificationType {
        case .like:
            action = AttributedString(" liked your photo")
        case .comment:
            action = AttributedString(" commented on your photo")
        case .follow:
            action = AttributedString(" started following you")
        }
        action.font = .subheadline
        
        return string + action
    }
    
    private var notificationIcon: some View {
        Group {
            switch notification.notificationType {
            case .like:
                Image(systemName: "heart.fill")
                    .foregroundStyle(.red)
            case .comment:
                Image(systemName: "bubble.right.fill")
                    .foregroundStyle(.blue)
            case .follow:
                Image(systemName: "person.badge.plus")
                    .foregroundStyle(.green)
            }
        }
        .font(.caption)
    }
}

#Preview {
    NotificationsView(
        store: Store(initialState: NotificationsFeature.State()) {
            NotificationsFeature()
        } withDependencies: {
            $0.notificationClient = .previewValue
        }
    )
}
