import ComposableArchitecture
import Foundation

// MARK: - Auth Client Dependency

/// TCA Dependency for authentication operations
struct AuthClient {
    var signUp: @Sendable (String, String, String, String) async throws -> Void
    var signIn: @Sendable (String, String) async throws -> Void
    var signOut: @Sendable () async throws -> Void
    var currentUserId: @Sendable () async -> UUID?
    var currentUser: @Sendable () async throws -> User?
    var observeAuthChanges: @Sendable () -> AsyncStream<AuthState>
}

enum AuthState: Equatable {
    case authenticated(UUID)
    case unauthenticated
}

extension AuthClient: DependencyKey {
    static let liveValue = AuthClient(
        signUp: { email, password, username, displayName in
            _ = try await AuthService.shared.signUp(
                email: email,
                password: password,
                username: username,
                displayName: displayName
            )
        },
        signIn: { email, password in
            _ = try await AuthService.shared.signIn(email: email, password: password)
        },
        signOut: {
            try await AuthService.shared.signOut()
        },
        currentUserId: {
            await AuthService.shared.currentUserId()
        },
        currentUser: {
            guard let userId = await AuthService.shared.currentUserId() else {
                return nil
            }
            return try await ProfileService.shared.getProfile(userId: userId)
        },
        observeAuthChanges: {
            AsyncStream { continuation in
                Task {
                    // Check initial state
                    if let userId = await AuthService.shared.currentUserId() {
                        continuation.yield(.authenticated(userId))
                    } else {
                        continuation.yield(.unauthenticated)
                    }
                    
                    // Observe changes
                    for await event in await AuthService.shared.authStateChanges() {
                        switch event {
                        case .signedIn:
                            if let userId = await AuthService.shared.currentUserId() {
                                continuation.yield(.authenticated(userId))
                            }
                        case .signedOut, .userDeleted:
                            continuation.yield(.unauthenticated)
                        default:
                            break
                        }
                    }
                }
            }
        }
    )
    
    static let previewValue = AuthClient(
        signUp: { _, _, _, _ in },
        signIn: { _, _ in },
        signOut: { },
        currentUserId: { User.mock1.id },
        currentUser: { .mock1 },
        observeAuthChanges: {
            AsyncStream { continuation in
                continuation.yield(.authenticated(User.mock1.id))
            }
        }
    )
    
    static let testValue = AuthClient(
        signUp: unimplemented("\(Self.self).signUp"),
        signIn: unimplemented("\(Self.self).signIn"),
        signOut: unimplemented("\(Self.self).signOut"),
        currentUserId: unimplemented("\(Self.self).currentUserId"),
        currentUser: unimplemented("\(Self.self).currentUser"),
        observeAuthChanges: unimplemented("\(Self.self).observeAuthChanges")
    )
}

extension DependencyValues {
    var authClient: AuthClient {
        get { self[AuthClient.self] }
        set { self[AuthClient.self] = newValue }
    }
}

// MARK: - Profile Client Dependency

/// TCA Dependency for profile operations
struct ProfileClient {
    var getProfile: @Sendable (UUID) async throws -> User
    var getCurrentUserProfile: @Sendable () async throws -> User
    var updateProfile: @Sendable (String?, URL?) async throws -> User
    var searchProfiles: @Sendable (String) async throws -> [User]
}

extension ProfileClient: DependencyKey {
    static let liveValue = ProfileClient(
        getProfile: { userId in
            try await ProfileService.shared.getProfile(userId: userId)
        },
        getCurrentUserProfile: {
            try await ProfileService.shared.getCurrentUserProfile()
        },
        updateProfile: { displayName, avatarURL in
            try await ProfileService.shared.updateCurrentUserProfile(
                displayName: displayName,
                avatarURL: avatarURL
            )
        },
        searchProfiles: { query in
            try await ProfileService.shared.searchProfiles(query: query)
        }
    )
    
    static let previewValue = ProfileClient(
        getProfile: { _ in .mock1 },
        getCurrentUserProfile: { .mock1 },
        updateProfile: { _, _ in .mock1 },
        searchProfiles: { _ in [.mock1, .mock2, .mock3] }
    )
    
    static let testValue = ProfileClient(
        getProfile: unimplemented("\(Self.self).getProfile"),
        getCurrentUserProfile: unimplemented("\(Self.self).getCurrentUserProfile"),
        updateProfile: unimplemented("\(Self.self).updateProfile"),
        searchProfiles: unimplemented("\(Self.self).searchProfiles")
    )
}

extension DependencyValues {
    var profileClient: ProfileClient {
        get { self[ProfileClient.self] }
        set { self[ProfileClient.self] = newValue }
    }
}

// MARK: - Post Client Dependency

/// TCA Dependency for post operations
struct PostClient {
    var getTimeline: @Sendable (Int, Int) async throws -> [Post]
    var getExploreFeed: @Sendable (Int, Int) async throws -> [Post]
    var getUserPosts: @Sendable (UUID, Int, Int) async throws -> [Post]
    var getCurrentUserPosts: @Sendable (Int, Int) async throws -> [Post]
    var createPost: @Sendable (String?, [(URL, URL?, Date?)]) async throws -> Post
    var deletePost: @Sendable (UUID) async throws -> Void
    var getLastPostDate: @Sendable () async throws -> Date?
    var likePost: @Sendable (UUID) async throws -> Void
    var unlikePost: @Sendable (UUID) async throws -> Void
    var toggleLike: @Sendable (UUID) async throws -> Bool
    var getComments: @Sendable (UUID, Int, Int) async throws -> [Comment]
    var createComment: @Sendable (UUID, String) async throws -> Comment
    var deleteComment: @Sendable (UUID) async throws -> Void
}

extension PostClient: DependencyKey {
    static let liveValue = PostClient(
        getTimeline: { limit, offset in
            try await PostService.shared.getTimeline(limit: limit, offset: offset)
        },
        getExploreFeed: { limit, offset in
            try await PostService.shared.getExploreFeed(limit: limit, offset: offset)
        },
        getUserPosts: { userId, limit, offset in
            try await PostService.shared.getPostsByUser(userId: userId, limit: limit, offset: offset)
        },
        getCurrentUserPosts: { limit, offset in
            try await PostService.shared.getCurrentUserPosts(limit: limit, offset: offset)
        },
        createPost: { caption, photoURLs in
            try await PostService.shared.createPost(caption: caption, photoURLs: photoURLs)
        },
        deletePost: { postId in
            try await PostService.shared.deletePost(postId: postId)
        },
        getLastPostDate: {
            try await PostService.shared.getLastPostDate()
        },
        likePost: { postId in
            try await PostService.shared.likePost(postId: postId)
        },
        unlikePost: { postId in
            try await PostService.shared.unlikePost(postId: postId)
        },
        toggleLike: { postId in
            try await PostService.shared.toggleLike(postId: postId)
        },
        getComments: { postId, limit, offset in
            try await PostService.shared.getComments(postId: postId, limit: limit, offset: offset)
        },
        createComment: { postId, content in
            try await PostService.shared.createComment(postId: postId, content: content)
        },
        deleteComment: { commentId in
            try await PostService.shared.deleteComment(commentId: commentId)
        }
    )
    
    static let previewValue = PostClient(
        getTimeline: { _, _ in Post.mockPosts },
        getExploreFeed: { _, _ in Post.mockPosts },
        getUserPosts: { _, _, _ in Post.mockPosts },
        getCurrentUserPosts: { _, _ in Post.mockPosts.filter { $0.user?.username == "johndoe" } },
        createPost: { caption, _ in
            Post(userId: User.mock1.id, caption: caption, user: .mock1, photos: [.mock(index: 1)])
        },
        deletePost: { _ in },
        getLastPostDate: { Date().addingTimeInterval(-3600) },
        likePost: { _ in },
        unlikePost: { _ in },
        toggleLike: { _ in true },
        getComments: { _, _, _ in Comment.mockComments },
        createComment: { postId, content in
            Comment(userId: User.mock1.id, postId: postId, content: content, createdAt: Date(), user: .mock1)
        },
        deleteComment: { _ in }
    )
    
    static let testValue = PostClient(
        getTimeline: unimplemented("\(Self.self).getTimeline"),
        getExploreFeed: unimplemented("\(Self.self).getExploreFeed"),
        getUserPosts: unimplemented("\(Self.self).getUserPosts"),
        getCurrentUserPosts: unimplemented("\(Self.self).getCurrentUserPosts"),
        createPost: unimplemented("\(Self.self).createPost"),
        deletePost: unimplemented("\(Self.self).deletePost"),
        getLastPostDate: unimplemented("\(Self.self).getLastPostDate"),
        likePost: unimplemented("\(Self.self).likePost"),
        unlikePost: unimplemented("\(Self.self).unlikePost"),
        toggleLike: unimplemented("\(Self.self).toggleLike"),
        getComments: unimplemented("\(Self.self).getComments"),
        createComment: unimplemented("\(Self.self).createComment"),
        deleteComment: unimplemented("\(Self.self).deleteComment")
    )
}

extension DependencyValues {
    var postClient: PostClient {
        get { self[PostClient.self] }
        set { self[PostClient.self] = newValue }
    }
}

// MARK: - Storage Client Dependency

/// TCA Dependency for storage operations
struct StorageClient {
    var uploadPhoto: @Sendable (Data) async throws -> URL
    var uploadPhotoWithThumbnail: @Sendable (Data, Data) async throws -> (URL, URL)
    var uploadAvatar: @Sendable (Data) async throws -> URL
    var deletePhoto: @Sendable (URL) async throws -> Void
}

extension StorageClient: DependencyKey {
    static let liveValue = StorageClient(
        uploadPhoto: { imageData in
            try await StorageService.shared.uploadPhoto(imageData: imageData)
        },
        uploadPhotoWithThumbnail: { imageData, thumbnailData in
            let result = try await StorageService.shared.uploadPhotoWithThumbnail(
                imageData: imageData,
                thumbnailData: thumbnailData
            )
            return (result.url, result.thumbnailURL)
        },
        uploadAvatar: { imageData in
            try await StorageService.shared.uploadAvatar(imageData: imageData)
        },
        deletePhoto: { url in
            try await StorageService.shared.deletePhoto(url: url)
        }
    )
    
    static let previewValue = StorageClient(
        uploadPhoto: { _ in URL(string: "https://example.com/photo.jpg")! },
        uploadPhotoWithThumbnail: { _, _ in
            (URL(string: "https://example.com/photo.jpg")!,
             URL(string: "https://example.com/photo_thumb.jpg")!)
        },
        uploadAvatar: { _ in URL(string: "https://i.pravatar.cc/150?u=preview")! },
        deletePhoto: { _ in }
    )
    
    static let testValue = StorageClient(
        uploadPhoto: unimplemented("\(Self.self).uploadPhoto"),
        uploadPhotoWithThumbnail: unimplemented("\(Self.self).uploadPhotoWithThumbnail"),
        uploadAvatar: unimplemented("\(Self.self).uploadAvatar"),
        deletePhoto: unimplemented("\(Self.self).deletePhoto")
    )
}

extension DependencyValues {
    var storageClient: StorageClient {
        get { self[StorageClient.self] }
        set { self[StorageClient.self] = newValue }
    }
}

// MARK: - Follow Client Dependency

/// TCA Dependency for follow operations
struct FollowClient {
    var follow: @Sendable (UUID) async throws -> Void
    var unfollow: @Sendable (UUID) async throws -> Void
    var toggleFollow: @Sendable (UUID) async throws -> Bool
    var isFollowing: @Sendable (UUID) async throws -> Bool
    var getFollowingIds: @Sendable () async throws -> [UUID]
    var getFollowerCount: @Sendable (UUID) async throws -> Int
    var getFollowingCount: @Sendable (UUID) async throws -> Int
}

extension FollowClient: DependencyKey {
    static let liveValue = FollowClient(
        follow: { userId in
            try await FollowService.shared.follow(userId: userId)
        },
        unfollow: { userId in
            try await FollowService.shared.unfollow(userId: userId)
        },
        toggleFollow: { userId in
            try await FollowService.shared.toggleFollow(userId: userId)
        },
        isFollowing: { userId in
            try await FollowService.shared.isFollowing(userId: userId)
        },
        getFollowingIds: {
            try await FollowService.shared.getFollowingIds()
        },
        getFollowerCount: { userId in
            try await FollowService.shared.getFollowerCount(userId: userId)
        },
        getFollowingCount: { userId in
            try await FollowService.shared.getFollowingCount(userId: userId)
        }
    )
    
    static let previewValue = FollowClient(
        follow: { _ in },
        unfollow: { _ in },
        toggleFollow: { _ in true },
        isFollowing: { _ in false },
        getFollowingIds: { [User.mock2.id, User.mock3.id] },
        getFollowerCount: { _ in 42 },
        getFollowingCount: { _ in 23 }
    )
    
    static let testValue = FollowClient(
        follow: unimplemented("\(Self.self).follow"),
        unfollow: unimplemented("\(Self.self).unfollow"),
        toggleFollow: unimplemented("\(Self.self).toggleFollow"),
        isFollowing: unimplemented("\(Self.self).isFollowing"),
        getFollowingIds: unimplemented("\(Self.self).getFollowingIds"),
        getFollowerCount: unimplemented("\(Self.self).getFollowerCount"),
        getFollowingCount: unimplemented("\(Self.self).getFollowingCount")
    )
}

extension DependencyValues {
    var followClient: FollowClient {
        get { self[FollowClient.self] }
        set { self[FollowClient.self] = newValue }
    }
}

// MARK: - Notification Client Dependency

/// TCA Dependency for notification operations
struct NotificationClient {
    var getNotifications: @Sendable (Int, Int) async throws -> [AppNotification]
    var getUnreadCount: @Sendable () async throws -> Int
    var markAsRead: @Sendable (UUID) async throws -> Void
    var markAllAsRead: @Sendable () async throws -> Void
    var subscribeToNotifications: @Sendable () async -> AsyncStream<AppNotification>
    var unsubscribe: @Sendable () async -> Void
}

extension NotificationClient: DependencyKey {
    static let liveValue = NotificationClient(
        getNotifications: { limit, offset in
            try await NotificationService.shared.getNotifications(limit: limit, offset: offset)
        },
        getUnreadCount: {
            try await NotificationService.shared.getUnreadCount()
        },
        markAsRead: { notificationId in
            try await NotificationService.shared.markAsRead(notificationId: notificationId)
        },
        markAllAsRead: {
            try await NotificationService.shared.markAllAsRead()
        },
        subscribeToNotifications: {
            await NotificationService.shared.subscribeToNotifications()
        },
        unsubscribe: {
            await NotificationService.shared.unsubscribe()
        }
    )
    
    static let previewValue = NotificationClient(
        getNotifications: { _, _ in AppNotification.mockNotifications },
        getUnreadCount: { 2 },
        markAsRead: { _ in },
        markAllAsRead: { },
        subscribeToNotifications: {
            AsyncStream { continuation in
                // Simulate a notification after 2 seconds
                Task {
                    try? await Task.sleep(for: .seconds(2))
                    continuation.yield(AppNotification.mock1)
                }
            }
        },
        unsubscribe: { }
    )
    
    static let testValue = NotificationClient(
        getNotifications: unimplemented("\(Self.self).getNotifications"),
        getUnreadCount: unimplemented("\(Self.self).getUnreadCount"),
        markAsRead: unimplemented("\(Self.self).markAsRead"),
        markAllAsRead: unimplemented("\(Self.self).markAllAsRead"),
        subscribeToNotifications: unimplemented("\(Self.self).subscribeToNotifications"),
        unsubscribe: unimplemented("\(Self.self).unsubscribe")
    )
}

extension DependencyValues {
    var notificationClient: NotificationClient {
        get { self[NotificationClient.self] }
        set { self[NotificationClient.self] = newValue }
    }
}
