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
        var isUploadingAvatar: Bool = false
        var errorMessage: String?
        
        // For viewing other users' profiles
        var viewingUserId: UUID?
        
        var isCurrentUser: Bool {
            viewingUserId == nil
        }
        
        @Presents var destination: Destination.State?
    }
    
    struct ProfileStats: Equatable {
        var postsCount: Int = 0
        var followersCount: Int = 0
        var followingCount: Int = 0
    }
    
    enum Action {
        case onAppear
        case refresh
        case dataLoaded(Result<(User, [Post]), Error>)
        case signOutTapped
        case signOutCompleted(Result<Void, Error>)
        case avatarTapped
        case avatarSelected(Data)
        case avatarUploaded(Result<URL, Error>)
        case profileUpdated(Result<User, Error>)
        case likeTapped(Post)
        case likeCompleted(postId: UUID, isLiked: Bool)
        case commentsTapped(Post)
        case destination(PresentationAction<Destination.Action>)
        case delegate(Delegate)
        
        @CasePathable
        enum Delegate {
            case didSignOut
            case profileUpdated(User)
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
    
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                // For current user: user might be pre-loaded from AppFeature, but we still need posts
                // For other users: load both user and posts
                let needsUserLoad = state.user == nil
                let needsPostsLoad = state.posts.isEmpty
                
                guard needsUserLoad || needsPostsLoad else { return .none }
                
                state.isLoading = needsUserLoad // Only show loading if we need to fetch user
                state.errorMessage = nil
                let viewingUserId = state.viewingUserId
                let existingUser = state.user
                
                return .run { send in
                    do {
                        let user: User
                        let posts: [Post]
                        
                        if let userId = viewingUserId {
                            // Viewing another user's profile
                            user = try await profileClient.getProfile(userId)
                            posts = try await postClient.getUserPosts(userId, 20, 0)
                        } else {
                            // Current user's profile - use existing user if available
                            if let existingUser {
                                user = existingUser
                            } else {
                                user = try await profileClient.getCurrentUserProfile()
                            }
                            posts = try await postClient.getCurrentUserPosts(20, 0)
                        }
                        
                        await send(.dataLoaded(.success((user, posts))))
                    } catch {
                        await send(.dataLoaded(.failure(error)))
                    }
                }
                
            case .refresh:
                state.isLoading = true
                state.errorMessage = nil
                let viewingUserId = state.viewingUserId
                
                return .run { send in
                    do {
                        let user: User
                        let posts: [Post]
                        
                        if let userId = viewingUserId {
                            user = try await profileClient.getProfile(userId)
                            posts = try await postClient.getUserPosts(userId, 20, 0)
                        } else {
                            user = try await profileClient.getCurrentUserProfile()
                            posts = try await postClient.getCurrentUserPosts(20, 0)
                        }
                        
                        await send(.dataLoaded(.success((user, posts))))
                    } catch {
                        await send(.dataLoaded(.failure(error)))
                    }
                }
                
            case .dataLoaded(.success(let (user, posts))):
                state.isLoading = false
                state.user = user
                state.posts = IdentifiedArrayOf(uniqueElements: posts)
                state.stats = ProfileStats(
                    postsCount: posts.count,
                    followersCount: 0, // TODO: Implement followers
                    followingCount: 0  // TODO: Implement following
                )
                return .none
                
            case .dataLoaded(.failure(let error)):
                state.isLoading = false
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
