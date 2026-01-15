import ComposableArchitecture
import Foundation

@Reducer
struct PostDetailFeature {
    @ObservableState
    struct State: Equatable {
        var post: Post
        var isLiking: Bool = false
        var currentUserId: UUID?
        
        @Presents var destination: Destination.State?
    }
    
    enum Action {
        case onAppear
        case currentUserIdLoaded(UUID?)
        case likeTapped
        case likeCompleted(isLiked: Bool)
        case commentsTapped
        case profileTapped(User)
        case destination(PresentationAction<Destination.Action>)
    }
    
    @Reducer(state: .equatable)
    enum Destination {
        case comments(CommentsFeature)
        case profile(ProfileFeature)
    }
    
    @Dependency(\.postClient) var postClient
    @Dependency(\.authClient) var authClient
    
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                return .run { send in
                    let userId = await authClient.currentUserId()
                    await send(.currentUserIdLoaded(userId))
                }
                
            case .currentUserIdLoaded(let userId):
                state.currentUserId = userId
                return .none
                
            case .likeTapped:
                let postId = state.post.id
                let isCurrentlyLiked = state.post.isLikedByCurrentUser
                
                // Optimistic update
                state.post.isLikedByCurrentUser = !isCurrentlyLiked
                state.post.likesCount += isCurrentlyLiked ? -1 : 1
                state.isLiking = true
                
                return .run { send in
                    do {
                        let isNowLiked = try await postClient.toggleLike(postId)
                        await send(.likeCompleted(isLiked: isNowLiked))
                    } catch {
                        // Revert on failure
                        await send(.likeCompleted(isLiked: isCurrentlyLiked))
                    }
                }
                
            case .likeCompleted(let isLiked):
                state.isLiking = false
                // Sync with server response if different
                if state.post.isLikedByCurrentUser != isLiked {
                    state.post.isLikedByCurrentUser = isLiked
                    state.post.likesCount += isLiked ? 1 : -1
                }
                return .none
                
            case .commentsTapped:
                state.destination = .comments(CommentsFeature.State(post: state.post))
                return .none
                
            case .profileTapped(let user):
                state.destination = .profile(ProfileFeature.State(user: user, viewingUserId: user.id))
                return .none
                
            case .destination:
                return .none
            }
        }
        .ifLet(\.$destination, action: \.destination)
    }
}
