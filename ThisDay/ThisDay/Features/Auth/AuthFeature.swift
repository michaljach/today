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
        var isCheckingUsername: Bool = false
        var usernameAvailable: Bool? = nil
        
        enum Mode: Equatable {
            case signIn
            case signUp
        }
        
        var isUsernameFormatValid: Bool {
            Self.isValidUsernameFormat(username)
        }
        
        var isFormValid: Bool {
            switch mode {
            case .signIn:
                return !email.isEmpty && !password.isEmpty
            case .signUp:
                let basicFieldsValid = !email.isEmpty && !password.isEmpty && !username.isEmpty && !displayName.isEmpty
                let usernameValid = usernameAvailable == true && isUsernameFormatValid
                return basicFieldsValid && usernameValid
            }
        }
        
        /// Validates username format: only lowercase letters, numbers, and underscores allowed
        static func isValidUsernameFormat(_ username: String) -> Bool {
            let pattern = "^[a-z0-9_]+$"
            return username.range(of: pattern, options: .regularExpression) != nil
        }
        
        /// Sanitizes username by removing invalid characters
        static func sanitizeUsername(_ username: String) -> String {
            let lowercased = username.lowercased()
            return lowercased.filter { $0.isLetter || $0.isNumber || $0 == "_" }
        }
    }
    
    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case toggleMode
        case submitTapped
        case authResponse(Result<Void, Error>)
        case checkUsernameAvailability
        case usernameAvailabilityResult(Bool)
        case delegate(Delegate)
        
        @CasePathable
        enum Delegate {
            case didAuthenticate
        }
    }
    
    @Dependency(\.authClient) var authClient
    @Dependency(\.profileClient) var profileClient
    
    private enum CancelID {
        case usernameCheck
    }
    
    var body: some ReducerOf<Self> {
        BindingReducer()
        
        Reduce { state, action in
            switch action {
            case .binding(\.username):
                // Sanitize username - remove invalid characters and lowercase
                let sanitized = State.sanitizeUsername(state.username)
                if sanitized != state.username {
                    state.username = sanitized
                }
                
                // Reset availability when username changes
                state.usernameAvailable = nil
                state.errorMessage = nil
                
                // Don't check if empty or invalid format
                guard !state.username.isEmpty, state.isUsernameFormatValid else {
                    return .cancel(id: CancelID.usernameCheck)
                }
                
                // Debounce username availability check
                return .run { send in
                    try await Task.sleep(for: .milliseconds(500))
                    await send(.checkUsernameAvailability)
                }
                .cancellable(id: CancelID.usernameCheck, cancelInFlight: true)
                
            case .binding:
                state.errorMessage = nil
                return .none
                
            case .toggleMode:
                state.mode = state.mode == .signIn ? .signUp : .signIn
                state.errorMessage = nil
                state.usernameAvailable = nil
                state.isCheckingUsername = false
                return .cancel(id: CancelID.usernameCheck)
                
            case .checkUsernameAvailability:
                guard !state.username.isEmpty else { return .none }
                
                state.isCheckingUsername = true
                let username = state.username
                
                return .run { send in
                    do {
                        let isAvailable = try await profileClient.isUsernameAvailable(username)
                        await send(.usernameAvailabilityResult(isAvailable))
                    } catch {
                        await send(.usernameAvailabilityResult(false))
                    }
                }
                
            case .usernameAvailabilityResult(let isAvailable):
                state.isCheckingUsername = false
                state.usernameAvailable = isAvailable
                if !isAvailable {
                    state.errorMessage = "Username is already taken"
                }
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
