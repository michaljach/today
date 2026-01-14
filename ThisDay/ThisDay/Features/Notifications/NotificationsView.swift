import ComposableArchitecture
import SwiftUI

struct NotificationsView: View {
    @Bindable var store: StoreOf<NotificationsFeature>
    
    var body: some View {
        NavigationStack {
            Group {
                if store.isLoading {
                    ProgressView("Loading...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if store.notifications.isEmpty {
                    emptyState
                } else {
                    List(store.notifications) { notification in
                        NotificationRow(notification: notification)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
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
    let notification: NotificationItem
    
    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: notification.user.avatarURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                default:
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                }
            }
            .frame(width: 40, height: 40)
            .clipShape(Circle())
            
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
    }
    
    private var notificationText: AttributedString {
        var string = AttributedString(notification.user.displayName)
        string.font = .subheadline.bold()
        
        var action: AttributedString
        switch notification.type {
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
            switch notification.type {
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
        }
    )
}
