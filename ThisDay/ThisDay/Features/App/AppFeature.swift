import ComposableArchitecture
import Foundation

@Reducer
struct AppFeature {
    @ObservableState
    struct State: Equatable {
        var authState: AuthenticationState = .loading
        var selectedTab: Tab = .timeline
        var currentUser: User?
        var auth = AuthFeature.State()
        var timeline = TimelineFeature.State()
        var explore = ExploreFeature.State()
        var notifications = NotificationsFeature.State()
        var profile = ProfileFeature.State()
        @Presents var compose: ComposeFeature.State?
        
        /// The date of the user's last post (nil if never posted)
        var lastPostDate: Date?
        
        /// Whether the user can create a new post today
        var canPostToday: Bool {
            guard let lastPostDate else { return true }
            return !Calendar.current.isDateInToday(lastPostDate)
        }
        
        enum AuthenticationState: Equatable {
            case loading
            case authenticated(UUID)
            case unauthenticated
        }
        
        enum Tab: Equatable {
            case timeline
            case explore
            case notifications
            case profile
        }
    }
    
    enum Action {
        case onAppear
        case authStateChanged(AuthState)
        case tabSelected(State.Tab)
        case composeTapped
        case compose(PresentationAction<ComposeFeature.Action>)
        case auth(AuthFeature.Action)
        case timeline(TimelineFeature.Action)
        case explore(ExploreFeature.Action)
        case notifications(NotificationsFeature.Action)
        case profile(ProfileFeature.Action)
        case lastPostDateLoaded(Date?)
        case currentUserLoaded(Result<User, Error>)
    }
    
    @Dependency(\.authClient) var authClient
    @Dependency(\.postClient) var postClient
    @Dependency(\.profileClient) var profileClient
    
    var body: some ReducerOf<Self> {
        Scope(state: \.auth, action: \.auth) {
            AuthFeature()
        }
        Scope(state: \.timeline, action: \.timeline) {
            TimelineFeature()
        }
        Scope(state: \.explore, action: \.explore) {
            ExploreFeature()
        }
        Scope(state: \.notifications, action: \.notifications) {
            NotificationsFeature()
        }
        Scope(state: \.profile, action: \.profile) {
            ProfileFeature()
        }
        
        Reduce { state, action in
            switch action {
            case .onAppear:
                return .run { send in
                    for await authState in authClient.observeAuthChanges() {
                        await send(.authStateChanged(authState))
                    }
                }
                
            case .authStateChanged(let authState):
                switch authState {
                case .authenticated(let userId):
                    state.authState = .authenticated(userId)
                    // Reset features when user authenticates
                    state.timeline = TimelineFeature.State()
                    state.profile = ProfileFeature.State()
                    // Load the user's profile and last post date
                    return .merge(
                        .run { send in
                            // Small delay to ensure auth session is fully established
                            try? await Task.sleep(for: .milliseconds(100))
                            do {
                                let lastPostDate = try await postClient.getLastPostDate()
                                await send(.lastPostDateLoaded(lastPostDate))
                            } catch {
                                // If we can't fetch last post date, assume user can post
                                print("Failed to fetch last post date: \(error)")
                                await send(.lastPostDateLoaded(nil))
                            }
                        },
                        .run { send in
                            do {
                                let user = try await profileClient.getCurrentUserProfile()
                                await send(.currentUserLoaded(.success(user)))
                            } catch {
                                print("Failed to fetch current user profile: \(error)")
                                await send(.currentUserLoaded(.failure(error)))
                            }
                        }
                    )
                case .unauthenticated:
                    state.authState = .unauthenticated
                    // Reset everything on sign out
                    state.currentUser = nil
                    state.auth = AuthFeature.State()
                    state.timeline = TimelineFeature.State()
                    state.explore = ExploreFeature.State()
                    state.profile = ProfileFeature.State()
                    state.selectedTab = .timeline
                    state.lastPostDate = nil
                }
                return .none
                
            case .lastPostDateLoaded(let date):
                state.lastPostDate = date
                return .none
                
            case .currentUserLoaded(.success(let user)):
                state.currentUser = user
                // Set the user in profile feature so it doesn't need to load
                state.profile.user = user
                return .none
                
            case .currentUserLoaded(.failure):
                // Profile will load on its own when user navigates to it
                return .none
                
            case .tabSelected(let tab):
                state.selectedTab = tab
                return .none
                
            case .composeTapped:
                guard state.canPostToday else { return .none }
                state.compose = ComposeFeature.State()
                return .none
                
            case .compose(.presented(.delegate(.postCreated(var post)))):
                // Dismiss compose and refresh timeline
                state.compose = nil
                // Attach current user to the post so it displays correctly
                if post.user == nil {
                    post.user = state.currentUser
                }
                // Prepend the new post to the timeline
                state.timeline.posts.insert(post, at: 0)
                // Also add to profile posts if loaded
                if state.profile.isCurrentUser && !state.profile.posts.isEmpty {
                    state.profile.posts.insert(post, at: 0)
                    state.profile.stats.postsCount += 1
                }
                // Update last post date to now
                state.lastPostDate = post.createdAt
                return .none
                
            case .compose(.presented(.delegate(.dismissed))):
                state.compose = nil
                return .none
                
            case .compose:
                return .none
                
            case .auth(.delegate(.didAuthenticate)):
                // Auth state change will be picked up by the observer
                return .none
                
            case .profile(.delegate(.didSignOut)):
                // Auth state change will be picked up by the observer
                return .none
                
            case .profile(.delegate(.profileUpdated(let user))):
                // Sync updated profile back to app state
                state.currentUser = user
                return .none
                
            case .timeline(.deleteCompleted(.success(let postId))):
                // Also remove from profile posts if loaded
                if state.profile.posts[id: postId] != nil {
                    state.profile.posts.remove(id: postId)
                    state.profile.stats.postsCount = max(0, state.profile.stats.postsCount - 1)
                }
                return .none
                
            case .auth, .timeline, .explore, .notifications, .profile:
                return .none
            }
        }
        .ifLet(\.$compose, action: \.compose) {
            ComposeFeature()
        }
    }
}
