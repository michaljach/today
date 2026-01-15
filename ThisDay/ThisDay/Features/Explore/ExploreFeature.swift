import ComposableArchitecture
import Foundation

@Reducer
struct ExploreFeature {
    @ObservableState
    struct State: Equatable {
        var posts: IdentifiedArrayOf<Post> = []
        var suggestedUsers: [User] = []
        var searchQuery: String = ""
        var searchResults: [User] = []
        var isLoading: Bool = false
        var isRefreshing: Bool = false
        var isSearching: Bool = false
        var errorMessage: String?
        
        @Presents var destination: Destination.State?
    }
    
    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case onAppear
        case refresh
        case postsLoaded(Result<[Post], Error>)
        case suggestedUsersLoaded(Result<[User], Error>)
        case searchUsers
        case debouncedSearch
        case searchResultsLoaded(Result<[User], Error>)
        case clearSearch
        case userTapped(User)
        case destination(PresentationAction<Destination.Action>)
    }
    
    @Reducer(state: .equatable)
    enum Destination {
        case profile(ProfileFeature)
    }
    
    private enum CancelID { case search }
    
    @Dependency(\.postClient) var postClient
    @Dependency(\.profileClient) var profileClient
    @Dependency(\.continuousClock) var clock
    
    var body: some ReducerOf<Self> {
        BindingReducer()
        
        Reduce { state, action in
            switch action {
            case .binding(\.searchQuery):
                if state.searchQuery.isEmpty {
                    state.searchResults = []
                    state.isSearching = false
                    return .cancel(id: CancelID.search)
                }
                // Debounce: wait 300ms before searching
                return .run { send in
                    try await clock.sleep(for: .milliseconds(300))
                    await send(.debouncedSearch)
                }
                .cancellable(id: CancelID.search, cancelInFlight: true)
                
            case .binding:
                return .none
                
            case .onAppear:
                guard state.posts.isEmpty else { return .none }
                state.isLoading = true
                state.errorMessage = nil
                return .merge(
                    .run { send in
                        do {
                            // Use getExploreFeed to show all posts from all users
                            let posts = try await postClient.getExploreFeed(30, 0)
                            await send(.postsLoaded(.success(posts)))
                        } catch {
                            await send(.postsLoaded(.failure(error)))
                        }
                    },
                    .run { send in
                        do {
                            // Load suggested users with stats for instant profile display
                            let users = try await profileClient.getAllUsersWithStats(20)
                            await send(.suggestedUsersLoaded(.success(users)))
                        } catch {
                            await send(.suggestedUsersLoaded(.failure(error)))
                        }
                    }
                )
                
            case .refresh:
                state.isRefreshing = true
                state.errorMessage = nil
                return .merge(
                    .run { send in
                        do {
                            let posts = try await postClient.getExploreFeed(30, 0)
                            await send(.postsLoaded(.success(posts)))
                        } catch {
                            await send(.postsLoaded(.failure(error)))
                        }
                    },
                    .run { send in
                        do {
                            // Load suggested users with stats for instant profile display
                            let users = try await profileClient.getAllUsersWithStats(20)
                            await send(.suggestedUsersLoaded(.success(users)))
                        } catch {
                            await send(.suggestedUsersLoaded(.failure(error)))
                        }
                    }
                )
                
            case .postsLoaded(.success(let posts)):
                state.isLoading = false
                state.isRefreshing = false
                state.posts = IdentifiedArrayOf(uniqueElements: posts)
                return .none
                
            case .postsLoaded(.failure(let error)):
                state.isLoading = false
                state.isRefreshing = false
                state.errorMessage = error.localizedDescription
                return .none
                
            case .suggestedUsersLoaded(.success(let users)):
                state.suggestedUsers = users
                return .none
                
            case .suggestedUsersLoaded(.failure):
                // Silently fail - suggested users are not critical
                return .none
                
            case .searchUsers, .debouncedSearch:
                guard !state.searchQuery.isEmpty else { return .none }
                state.isSearching = true
                let query = state.searchQuery
                return .run { send in
                    do {
                        // Search with stats for instant profile display
                        let users = try await profileClient.searchProfilesWithStats(query)
                        await send(.searchResultsLoaded(.success(users)))
                    } catch {
                        await send(.searchResultsLoaded(.failure(error)))
                    }
                }
                .cancellable(id: CancelID.search, cancelInFlight: true)
                
            case .searchResultsLoaded(.success(let users)):
                state.isSearching = false
                state.searchResults = users
                return .none
                
            case .searchResultsLoaded(.failure):
                state.isSearching = false
                return .none
                
            case .clearSearch:
                state.searchQuery = ""
                state.searchResults = []
                state.isSearching = false
                return .none
                
            case .userTapped(let user):
                state.destination = .profile(ProfileFeature.State(user: user, viewingUserId: user.id))
                return .none
                
            case .destination:
                return .none
            }
        }
        .ifLet(\.$destination, action: \.destination)
    }
}
