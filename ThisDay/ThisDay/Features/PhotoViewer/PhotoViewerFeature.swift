import ComposableArchitecture
import Foundation

@Reducer
struct PhotoViewerFeature {
    @ObservableState
    struct State: Equatable {
        var post: Post
        var selectedIndex: Int
        var showInlineComments: Bool
        var showCommentsSheet: Bool = false
        
        // Child feature state
        var comments: CommentsFeature.State?
        
        var currentPhoto: Photo? {
            guard selectedIndex < post.photos.count else { return nil }
            return post.photos[selectedIndex]
        }
        
        init(post: Post, selectedIndex: Int = 0, showInlineComments: Bool = false) {
            self.post = post
            self.selectedIndex = selectedIndex
            self.showInlineComments = showInlineComments
            
            if showInlineComments {
                self.comments = CommentsFeature.State(post: post)
            }
        }
    }
    
    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case onAppear
        case dismiss
        case userTapped(User)
        case showCommentsSheet
        case hideCommentsSheet
        case comments(CommentsFeature.Action)
        
        // Delegate actions for parent to handle
        enum Delegate: Equatable {
            case dismiss
            case userTapped(User)
        }
        case delegate(Delegate)
    }
    
    @Dependency(\.dismiss) var dismiss
    
    var body: some ReducerOf<Self> {
        BindingReducer()
        
        Reduce { state, action in
            switch action {
            case .binding:
                return .none
                
            case .onAppear:
                if state.showInlineComments {
                    return .send(.comments(.onAppear))
                }
                return .none
                
            case .dismiss:
                return .send(.delegate(.dismiss))
                
            case .userTapped(let user):
                return .send(.delegate(.userTapped(user)))
                
            case .showCommentsSheet:
                state.showCommentsSheet = true
                return .none
                
            case .hideCommentsSheet:
                state.showCommentsSheet = false
                return .none
                
            case .comments:
                return .none
                
            case .delegate:
                return .none
            }
        }
        .ifLet(\.comments, action: \.comments) {
            CommentsFeature()
        }
    }
}
