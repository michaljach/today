import ComposableArchitecture
import Foundation

@Reducer
struct ProfileFeature {
    @ObservableState
    struct State: Equatable {
        var user: User?
        var posts: IdentifiedArrayOf<Post> = []
        var stats: ProfileStats = ProfileStats()
        var isLoading: Bool = false
        var isLoadingPosts: Bool = false
        var isUploadingAvatar: Bool = false
        var isTogglingFollow: Bool = false
        var isFollowing: Bool = false
        var errorMessage: String?
        
        // For viewing other users' profiles
        var viewingUserId: UUID?
        
        var isCurrentUser: Bool {
            viewingUserId == nil
        }
        
        @Presents var destination: Destination.State?
        
        init(user: User? = nil, viewingUserId: UUID? = nil) {
            self.user = user
            self.viewingUserId = viewingUserId
        }
    }
    
    struct ProfileStats: Equatable {
        var postsCount: Int = 0
        var followersCount: Int = 0
        var followingCount: Int = 0
    }
    
    enum Action {
        case onAppear
        case refresh
        case dataLoaded(Result<(User, [Post], Int, Int, Bool), Error>)
        case signOutTapped
        case signOutCompleted(Result<Void, Error>)
        case avatarTapped
        case avatarSelected(Data)
        case avatarUploaded(Result<URL, Error>)
        case profileUpdated(Result<User, Error>)
        case followTapped
        case followCompleted(Result<Bool, Error>)
        case likeTapped(Post)
        case likeCompleted(postId: UUID, isLiked: Bool)
        case commentsTapped(Post)
        case destination(PresentationAction<Destination.Action>)
        case delegate(Delegate)
        
        @CasePathable
        enum Delegate {
            case didSignOut
            case profileUpdated(User)
            case followStateChanged(isFollowing: Bool)
        }
    }
    
    @Reducer(state: .equatable)
    enum Destination {
        case comments(CommentsFeature)
    }
    
    @Dependency(\.authClient) var authClient
    @Dependency(\.profileClient) var profileClient
    @Dependency(\.postClient) var postClient
    @Dependency(\.storageClient) var storageClient
    @Dependency(\.followClient) var followClient
    
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                // For current user: user might be pre-loaded from AppFeature, but we still need posts
                // For other users: user might be passed in, but we still need posts and stats
                let needsUserLoad = state.user == nil
                let needsPostsLoad = state.posts.isEmpty
                
                // If we already have user with stats, use them immediately
                if let user = state.user {
                    if let postsCount = user.postsCount {
                        state.stats.postsCount = postsCount
                    }
                    if let followersCount = user.followersCount {
                        state.stats.followersCount = followersCount
                    }
                    if let followingCount = user.followingCount {
                        state.stats.followingCount = followingCount
                    }
                }
                
                // Check if we have all stats from user object
                let hasAllStats = state.user?.postsCount != nil && 
                                  state.user?.followersCount != nil && 
                                  state.user?.followingCount != nil
                
                guard needsUserLoad || needsPostsLoad else { return .none }
                
                state.isLoading = needsUserLoad // Only show full loading if we need to fetch user
                state.isLoadingPosts = needsPostsLoad && !needsUserLoad // Show posts loading if user is already available
                state.errorMessage = nil
                let viewingUserId = state.viewingUserId
                let existingUser = state.user
                let needsStatsFetch = !hasAllStats
                
                return .run { [followClient, profileClient, postClient] send in
                    do {
                        let user: User
                        let posts: [Post]
                        var followersCount: Int = 0
                        var followingCount: Int = 0
                        var isFollowing = false
                        
                        if let userId = viewingUserId {
                            // Viewing another user's profile
                            if let existingUser {
                                user = existingUser
                                // Use pre-fetched stats if available
                                followersCount = existingUser.followersCount ?? 0
                                followingCount = existingUser.followingCount ?? 0
                            } else {
                                user = try await profileClient.getProfile(userId)
                            }
                            posts = try await postClient.getUserPosts(userId, 20, 0)
                            
                            // Only fetch stats if not already available
                            if needsStatsFetch {
                                followersCount = try await followClient.getFollowerCount(userId)
                                followingCount = try await followClient.getFollowingCount(userId)
                            }
                            isFollowing = try await followClient.isFollowing(userId)
                        } else {
                            // Current user's profile - use existing user if available
                            if let existingUser {
                                user = existingUser
                                // Use pre-fetched stats if available
                                followersCount = existingUser.followersCount ?? 0
                                followingCount = existingUser.followingCount ?? 0
                            } else {
                                user = try await profileClient.getCurrentUserProfile()
                            }
                            posts = try await postClient.getCurrentUserPosts(20, 0)
                            
                            // Only fetch stats if not already available
                            if needsStatsFetch {
                                followersCount = try await followClient.getFollowerCount(user.id)
                                followingCount = try await followClient.getFollowingCount(user.id)
                            }
                        }
                        
                        await send(.dataLoaded(.success((user, posts, followersCount, followingCount, isFollowing))))
                    } catch {
                        await send(.dataLoaded(.failure(error)))
                    }
                }
                
            case .refresh:
                state.isLoading = true
                state.errorMessage = nil
                let viewingUserId = state.viewingUserId
                
                return .run { [followClient] send in
                    do {
                        let user: User
                        let posts: [Post]
                        let followersCount: Int
                        let followingCount: Int
                        var isFollowing = false
                        
                        if let userId = viewingUserId {
                            user = try await profileClient.getProfile(userId)
                            posts = try await postClient.getUserPosts(userId, 20, 0)
                            followersCount = try await followClient.getFollowerCount(userId)
                            followingCount = try await followClient.getFollowingCount(userId)
                            isFollowing = try await followClient.isFollowing(userId)
                        } else {
                            user = try await profileClient.getCurrentUserProfile()
                            posts = try await postClient.getCurrentUserPosts(20, 0)
                            followersCount = try await followClient.getFollowerCount(user.id)
                            followingCount = try await followClient.getFollowingCount(user.id)
                        }
                        
                        await send(.dataLoaded(.success((user, posts, followersCount, followingCount, isFollowing))))
                    } catch {
                        await send(.dataLoaded(.failure(error)))
                    }
                }
                
            case .dataLoaded(.success(let (user, posts, followersCount, followingCount, isFollowing))):
                state.isLoading = false
                state.isLoadingPosts = false
                state.user = user
                state.posts = IdentifiedArrayOf(uniqueElements: posts)
                state.stats = ProfileStats(
                    postsCount: posts.count,
                    followersCount: followersCount,
                    followingCount: followingCount
                )
                state.isFollowing = isFollowing
                return .none
                
            case .dataLoaded(.failure(let error)):
                state.isLoading = false
                state.isLoadingPosts = false
                state.errorMessage = error.localizedDescription
                return .none
                
            case .signOutTapped:
                return .run { send in
                    do {
                        try await authClient.signOut()
                        await send(.signOutCompleted(.success(())))
                    } catch {
                        await send(.signOutCompleted(.failure(error)))
                    }
                }
                
            case .signOutCompleted(.success):
                return .send(.delegate(.didSignOut))
                
            case .signOutCompleted(.failure(let error)):
                state.errorMessage = error.localizedDescription
                return .none
                
            case .avatarTapped:
                // This action is handled by the view to show the photo picker
                return .none
                
            case .avatarSelected(let imageData):
                state.isUploadingAvatar = true
                state.errorMessage = nil
                
                return .run { send in
                    do {
                        let avatarURL = try await storageClient.uploadAvatar(imageData)
                        await send(.avatarUploaded(.success(avatarURL)))
                    } catch {
                        await send(.avatarUploaded(.failure(error)))
                    }
                }
                
            case .avatarUploaded(.success(let avatarURL)):
                // Now update the profile with the new avatar URL
                return .run { send in
                    do {
                        let updatedUser = try await profileClient.updateProfile(nil, avatarURL)
                        await send(.profileUpdated(.success(updatedUser)))
                    } catch {
                        await send(.profileUpdated(.failure(error)))
                    }
                }
                
            case .avatarUploaded(.failure(let error)):
                state.isUploadingAvatar = false
                state.errorMessage = error.localizedDescription
                return .none
                
            case .profileUpdated(.success(let user)):
                state.isUploadingAvatar = false
                state.user = user
                // Notify parent that profile was updated
                return state.isCurrentUser ? .send(.delegate(.profileUpdated(user))) : .none
                
            case .profileUpdated(.failure(let error)):
                state.isUploadingAvatar = false
                state.errorMessage = error.localizedDescription
                return .none
                
            case .followTapped:
                guard let userId = state.viewingUserId else { return .none }
                
                state.isTogglingFollow = true
                let wasFollowing = state.isFollowing
                
                // Optimistic update
                state.isFollowing = !wasFollowing
                state.stats.followersCount += wasFollowing ? -1 : 1
                
                return .run { [followClient] send in
                    do {
                        let isNowFollowing = try await followClient.toggleFollow(userId)
                        await send(.followCompleted(.success(isNowFollowing)))
                    } catch {
                        await send(.followCompleted(.failure(error)))
                    }
                }
                
            case .followCompleted(.success(let isFollowing)):
                state.isTogglingFollow = false
                // Sync with actual state if different
                if state.isFollowing != isFollowing {
                    state.isFollowing = isFollowing
                    // Recalculate followers count
                    state.stats.followersCount += isFollowing ? 1 : -1
                }
                // Notify parent to refresh timeline since followed users changed
                return .send(.delegate(.followStateChanged(isFollowing: isFollowing)))
                
            case .followCompleted(.failure(let error)):
                state.isTogglingFollow = false
                // Revert optimistic update
                state.isFollowing = !state.isFollowing
                state.stats.followersCount += state.isFollowing ? 1 : -1
                state.errorMessage = error.localizedDescription
                return .none
                
            case .likeTapped(let post):
                let postId = post.id
                let isCurrentlyLiked = post.isLikedByCurrentUser
                
                // Optimistic update
                if var updatedPost = state.posts[id: postId] {
                    updatedPost.isLikedByCurrentUser = !isCurrentlyLiked
                    updatedPost.likesCount += isCurrentlyLiked ? -1 : 1
                    state.posts[id: postId] = updatedPost
                }
                
                return .run { send in
                    do {
                        let isNowLiked = try await postClient.toggleLike(postId)
                        await send(.likeCompleted(postId: postId, isLiked: isNowLiked))
                    } catch {
                        // Revert on failure
                        await send(.likeCompleted(postId: postId, isLiked: isCurrentlyLiked))
                    }
                }
                
            case .likeCompleted(let postId, let isLiked):
                // Sync with server response (in case optimistic update was wrong)
                if var post = state.posts[id: postId] {
                    if post.isLikedByCurrentUser != isLiked {
                        post.isLikedByCurrentUser = isLiked
                        post.likesCount += isLiked ? 1 : -1
                        state.posts[id: postId] = post
                    }
                }
                return .none
                
            case .commentsTapped(let post):
                state.destination = .comments(CommentsFeature.State(post: post))
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
