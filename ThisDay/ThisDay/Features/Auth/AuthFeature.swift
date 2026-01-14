import ComposableArchitecture
import Foundation

@Reducer
struct AuthFeature {
    @ObservableState
    struct State: Equatable {
        var mode: Mode = .signIn
        var email: String = ""
        var password: String = ""
        var username: String = ""
        var displayName: String = ""
        var isLoading: Bool = false
        var errorMessage: String?
        
        enum Mode: Equatable {
            case signIn
            case signUp
        }
        
        var isFormValid: Bool {
            switch mode {
            case .signIn:
                return !email.isEmpty && !password.isEmpty
            case .signUp:
                return !email.isEmpty && !password.isEmpty && !username.isEmpty && !displayName.isEmpty
            }
        }
    }
    
    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case toggleMode
        case submitTapped
        case authResponse(Result<Void, Error>)
        case delegate(Delegate)
        
        @CasePathable
        enum Delegate {
            case didAuthenticate
        }
    }
    
    @Dependency(\.authClient) var authClient
    
    var body: some ReducerOf<Self> {
        BindingReducer()
        
        Reduce { state, action in
            switch action {
            case .binding:
                state.errorMessage = nil
                return .none
                
            case .toggleMode:
                state.mode = state.mode == .signIn ? .signUp : .signIn
                state.errorMessage = nil
                return .none
                
            case .submitTapped:
                guard state.isFormValid else { return .none }
                
                state.isLoading = true
                state.errorMessage = nil
                
                let email = state.email
                let password = state.password
                let username = state.username
                let displayName = state.displayName
                let mode = state.mode
                
                return .run { send in
                    do {
                        switch mode {
                        case .signIn:
                            try await authClient.signIn(email, password)
                        case .signUp:
                            try await authClient.signUp(email, password, username, displayName)
                        }
                        await send(.authResponse(.success(())))
                    } catch {
                        await send(.authResponse(.failure(error)))
                    }
                }
                
            case .authResponse(.success):
                state.isLoading = false
                return .send(.delegate(.didAuthenticate))
                
            case .authResponse(.failure(let error)):
                state.isLoading = false
                state.errorMessage = error.localizedDescription
                return .none
                
            case .delegate:
                return .none
            }
        }
    }
}
