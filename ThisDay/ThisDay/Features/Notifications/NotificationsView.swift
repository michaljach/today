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
                    List(store.groupedNotifications) { group in
                        GroupedNotificationRow(
                            group: group,
                            onActorTapped: { actor in
                                store.send(.actorTapped(actor))
                            },
                            onNotificationTapped: {
                                store.send(.groupedNotificationTapped(group))
                            }
                        )
                        .listRowBackground(group.isRead ? Color.clear : Color.accentColor.opacity(0.05))
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
    let onActorTapped: (User) -> Void
    let onNotificationTapped: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Avatar - tappable to go to profile
            if let actor = notification.actor {
                Button {
                    onActorTapped(actor)
                } label: {
                    AvatarView(url: actor.avatarURL, size: 44)
                }
                .buttonStyle(.plain)
            } else {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 44, height: 44)
            }
            
            // Content - tappable to go to post or profile depending on type
            Button {
                onNotificationTapped()
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(notificationText)
                        .font(.subheadline)
                    
                    Text(notification.createdAt.timeAgoDisplay())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            notificationIcon
        }
        .padding(.vertical, 4)
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
                    .foregroundStyle(Color.accentColor)
            case .follow:
                Image(systemName: "person.badge.plus")
                    .foregroundStyle(.green)
            }
        }
        .font(.caption)
    }
}

// MARK: - Grouped Notification Row

struct GroupedNotificationRow: View {
    let group: GroupedNotification
    let onActorTapped: (User) -> Void
    let onNotificationTapped: () -> Void
    
    private let avatarSize: CGFloat = 44
    private let stackedAvatarSize: CGFloat = 32
    private let maxVisibleAvatars = 3
    
    var body: some View {
        HStack(spacing: 12) {
            // Stacked avatars
            stackedAvatars
            
            // Content - tappable to go to post or profile depending on type
            Button {
                onNotificationTapped()
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(notificationText)
                        .font(.subheadline)
                        .multilineTextAlignment(.leading)
                    
                    Text(group.latestDate.timeAgoDisplay())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            notificationIcon
        }
        .padding(.vertical, 4)
    }
    
    @ViewBuilder
    private var stackedAvatars: some View {
        if group.actors.count == 1, let actor = group.primaryActor {
            // Single actor - show regular avatar
            Button {
                onActorTapped(actor)
            } label: {
                AvatarView(url: actor.avatarURL, size: avatarSize)
            }
            .buttonStyle(.plain)
        } else {
            // Multiple actors - show stacked avatars
            let visibleActors = Array(group.actors.prefix(maxVisibleAvatars))
            let overlapOffset: CGFloat = 16
            
            ZStack(alignment: .leading) {
                ForEach(Array(visibleActors.enumerated().reversed()), id: \.element.id) { index, actor in
                    Button {
                        onActorTapped(actor)
                    } label: {
                        AvatarView(url: actor.avatarURL, size: stackedAvatarSize)
                            .overlay(
                                Circle()
                                    .stroke(Color(uiColor: .systemBackground), lineWidth: 2)
                            )
                    }
                    .buttonStyle(.plain)
                    .offset(x: CGFloat(index) * overlapOffset)
                }
            }
            .frame(
                width: stackedAvatarSize + CGFloat(visibleActors.count - 1) * overlapOffset,
                height: stackedAvatarSize
            )
            .frame(width: avatarSize, alignment: .leading)
        }
    }
    
    private var notificationText: AttributedString {
        let primaryName = group.primaryActor?.displayName ?? "Someone"
        var string = AttributedString(primaryName)
        string.font = .subheadline.bold()
        
        // Add "and X others" if there are more actors
        if group.otherActorsCount > 0 {
            var others: AttributedString
            if group.otherActorsCount == 1 {
                others = AttributedString(" and 1 other")
            } else {
                others = AttributedString(" and \(group.otherActorsCount) others")
            }
            others.font = .subheadline
            string = string + others
        }
        
        // Add the action text
        var action: AttributedString
        switch group.type {
        case .like:
            action = AttributedString(" liked your photo")
        case .comment:
            action = AttributedString(" commented on your photo")
        case .follow:
            if group.actors.count > 1 {
                action = AttributedString(" started following you")
            } else {
                action = AttributedString(" started following you")
            }
        }
        action.font = .subheadline
        
        return string + action
    }
    
    private var notificationIcon: some View {
        Group {
            switch group.type {
            case .like:
                Image(systemName: "heart.fill")
                    .foregroundStyle(.red)
            case .comment:
                Image(systemName: "bubble.right.fill")
                    .foregroundStyle(Color.accentColor)
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
