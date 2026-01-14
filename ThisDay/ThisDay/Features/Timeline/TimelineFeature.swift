import ComposableArchitecture
import Foundation

@Reducer
struct TimelineFeature {
    @ObservableState
    struct State: Equatable {
        var posts: IdentifiedArrayOf<Post> = []
        var isLoading: Bool = false
        var isRefreshing: Bool = false
        var errorMessage: String?
        var hasMorePosts: Bool = true
        var currentPage: Int = 0
        var currentUserId: UUID?
        var postToDelete: Post?
        var isDeleting: Bool = false
        
        @Presents var destination: Destination.State?
        
        static let pageSize = 20
    }
    
    enum Action {
        case onAppear
        case refresh
        case loadMore
        case postsLoaded(Result<[Post], Error>)
        case morePostsLoaded(Result<[Post], Error>)
        case profileTapped(User)
        case destination(PresentationAction<Destination.Action>)
        case deletePostTapped(Post)
        case confirmDelete
        case cancelDelete
        case deleteCompleted(Result<UUID, Error>)
        case currentUserIdLoaded(UUID?)
        case likeTapped(Post)
        case likeCompleted(postId: UUID, isLiked: Bool)
        case commentsTapped(Post)
    }
    
    @Reducer(state: .equatable)
    enum Destination {
        case profile(ProfileFeature)
        case comments(CommentsFeature)
    }
    
    @Dependency(\.postClient) var postClient
    @Dependency(\.authClient) var authClient
    
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                guard state.posts.isEmpty else { return .none }
                state.isLoading = true
                state.errorMessage = nil
                return .merge(
                    .run { send in
                        do {
                            let posts = try await postClient.getTimeline(State.pageSize, 0)
                            await send(.postsLoaded(.success(posts)))
                        } catch {
                            await send(.postsLoaded(.failure(error)))
                        }
                    },
                    .run { [authClient] send in
                        let userId = await authClient.currentUserId()
                        await send(.currentUserIdLoaded(userId))
                    }
                )
                
            case .refresh:
                state.isRefreshing = true
                state.errorMessage = nil
                state.currentPage = 0
                return .run { send in
                    do {
                        let posts = try await postClient.getTimeline(State.pageSize, 0)
                        await send(.postsLoaded(.success(posts)))
                    } catch {
                        await send(.postsLoaded(.failure(error)))
                    }
                }
                
            case .loadMore:
                guard !state.isLoading && state.hasMorePosts else { return .none }
                let offset = (state.currentPage + 1) * State.pageSize
                return .run { send in
                    do {
                        let posts = try await postClient.getTimeline(State.pageSize, offset)
                        await send(.morePostsLoaded(.success(posts)))
                    } catch {
                        await send(.morePostsLoaded(.failure(error)))
                    }
                }
                
            case .postsLoaded(.success(let posts)):
                state.isLoading = false
                state.isRefreshing = false
                state.currentPage = 0
                state.hasMorePosts = posts.count >= State.pageSize
                state.posts = IdentifiedArrayOf(uniqueElements: posts)
                return .none
                
            case .postsLoaded(.failure(let error)):
                state.isLoading = false
                state.isRefreshing = false
                state.errorMessage = error.localizedDescription
                return .none
                
            case .morePostsLoaded(.success(let posts)):
                state.currentPage += 1
                state.hasMorePosts = posts.count >= State.pageSize
                for post in posts {
                    state.posts.append(post)
                }
                return .none
                
            case .morePostsLoaded(.failure):
                // Silently fail for pagination errors
                return .none
                
            case .profileTapped(let user):
                state.destination = .profile(ProfileFeature.State(viewingUserId: user.id))
                return .none
                
            case .deletePostTapped(let post):
                state.postToDelete = post
                return .none
                
            case .confirmDelete:
                guard let post = state.postToDelete else { return .none }
                state.isDeleting = true
                let postId = post.id
                return .run { send in
                    do {
                        try await postClient.deletePost(postId)
                        await send(.deleteCompleted(.success(postId)))
                    } catch {
                        await send(.deleteCompleted(.failure(error)))
                    }
                }
                
            case .cancelDelete:
                state.postToDelete = nil
                return .none
                
            case .deleteCompleted(.success(let postId)):
                state.isDeleting = false
                state.postToDelete = nil
                state.posts.remove(id: postId)
                return .none
                
            case .deleteCompleted(.failure):
                state.isDeleting = false
                state.postToDelete = nil
                // Could show error message here
                return .none
                
            case .currentUserIdLoaded(let userId):
                state.currentUserId = userId
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
            }
        }
        .ifLet(\.$destination, action: \.destination)
    }
}
