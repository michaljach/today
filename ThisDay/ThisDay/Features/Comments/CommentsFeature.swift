import ComposableArchitecture
import Foundation

@Reducer
struct CommentsFeature {
    @ObservableState
    struct State: Equatable {
        let postId: UUID
        var isLikedByCurrentUser: Bool
        var likesCount: Int
        var comments: IdentifiedArrayOf<Comment> = []
        var newCommentText: String = ""
        var isLoading: Bool = false
        var isSubmitting: Bool = false
        var errorMessage: String?
        var currentUserId: UUID?
        
        init(post: Post) {
            self.postId = post.id
            self.isLikedByCurrentUser = post.isLikedByCurrentUser
            self.likesCount = post.likesCount
        }
        
        init(
            post: Post,
            comments: IdentifiedArrayOf<Comment> = [],
            isLoading: Bool = false,
            currentUserId: UUID? = nil
        ) {
            self.postId = post.id
            self.isLikedByCurrentUser = post.isLikedByCurrentUser
            self.likesCount = post.likesCount
            self.comments = comments
            self.isLoading = isLoading
            self.currentUserId = currentUserId
        }
    }
    
    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case onAppear
        case loadComments
        case commentsLoaded(Result<[Comment], Error>)
        case submitComment
        case commentCreated(Result<Comment, Error>)
        case deleteComment(Comment)
        case commentDeleted(Result<UUID, Error>)
        case userTapped(User)
        case currentUserIdLoaded(UUID?)
        case likeTapped
        case likeCompleted(isLiked: Bool)
    }
    
    @Dependency(\.postClient) var postClient
    @Dependency(\.authClient) var authClient
    
    var body: some ReducerOf<Self> {
        BindingReducer()
        
        Reduce { state, action in
            switch action {
            case .binding:
                return .none
                
            case .onAppear:
                return .run { send in
                    let userId = await authClient.currentUserId()
                    await send(.currentUserIdLoaded(userId))
                    await send(.loadComments)
                }
                
            case .currentUserIdLoaded(let userId):
                state.currentUserId = userId
                return .none
                
            case .loadComments:
                state.isLoading = true
                state.errorMessage = nil
                let postId = state.postId
                return .run { send in
                    do {
                        let comments = try await postClient.getComments(postId, 50, 0)
                        await send(.commentsLoaded(.success(comments)))
                    } catch {
                        await send(.commentsLoaded(.failure(error)))
                    }
                }
                
            case .commentsLoaded(.success(let comments)):
                state.isLoading = false
                state.comments = IdentifiedArrayOf(uniqueElements: comments)
                return .none
                
            case .commentsLoaded(.failure(let error)):
                state.isLoading = false
                state.errorMessage = error.localizedDescription
                return .none
                
            case .submitComment:
                let content = state.newCommentText.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !content.isEmpty else { return .none }
                
                state.isSubmitting = true
                state.errorMessage = nil
                let postId = state.postId
                return .run { send in
                    do {
                        let comment = try await postClient.createComment(postId, content)
                        await send(.commentCreated(.success(comment)))
                    } catch {
                        await send(.commentCreated(.failure(error)))
                    }
                }
                
            case .commentCreated(.success(let comment)):
                state.isSubmitting = false
                state.newCommentText = ""
                state.comments.append(comment)
                return .none
                
            case .commentCreated(.failure(let error)):
                state.isSubmitting = false
                state.errorMessage = error.localizedDescription
                return .none
                
            case .deleteComment(let comment):
                let commentId = comment.id
                return .run { send in
                    do {
                        try await postClient.deleteComment(commentId)
                        await send(.commentDeleted(.success(commentId)))
                    } catch {
                        await send(.commentDeleted(.failure(error)))
                    }
                }
                
            case .commentDeleted(.success(let commentId)):
                state.comments.remove(id: commentId)
                return .none
                
            case .commentDeleted(.failure(let error)):
                state.errorMessage = error.localizedDescription
                return .none
                
            case .userTapped:
                // Handled by parent
                return .none
                
            case .likeTapped:
                let postId = state.postId
                let isCurrentlyLiked = state.isLikedByCurrentUser
                
                // Optimistic update
                state.isLikedByCurrentUser = !isCurrentlyLiked
                state.likesCount += isCurrentlyLiked ? -1 : 1
                
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
                // Sync with server response (in case optimistic update was wrong)
                if state.isLikedByCurrentUser != isLiked {
                    state.isLikedByCurrentUser = isLiked
                    state.likesCount += isLiked ? 1 : -1
                }
                return .none
            }
        }
    }
}
