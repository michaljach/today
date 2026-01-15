import ComposableArchitecture
import Foundation

@Reducer
struct EditProfileFeature {
    @ObservableState
    struct State: Equatable {
        var user: User
        var email: String
        
        // Form fields
        var displayName: String
        var username: String
        var newEmail: String
        var currentPassword: String = ""
        var newPassword: String = ""
        var confirmPassword: String = ""
        
        // UI state
        var isSaving: Bool = false
        var isCheckingUsername: Bool = false
        var usernameAvailable: Bool? = nil
        var errorMessage: String?
        var successMessage: String?
        
        var isUsernameFormatValid: Bool {
            Self.isValidUsernameFormat(username)
        }
        
        // Track which fields have changed
        var hasProfileChanges: Bool {
            displayName != user.displayName || username != user.username
        }
        
        var hasEmailChange: Bool {
            newEmail != email && !newEmail.isEmpty
        }
        
        var hasPasswordChange: Bool {
            !newPassword.isEmpty && !confirmPassword.isEmpty
        }
        
        var passwordsMatch: Bool {
            newPassword == confirmPassword
        }
        
        var canSave: Bool {
            guard !isSaving else { return false }
            
            // Check if there are any changes
            let hasChanges = hasProfileChanges || hasEmailChange || hasPasswordChange
            guard hasChanges else { return false }
            
            // Validate username
            if username != user.username {
                guard usernameAvailable == true && isUsernameFormatValid else { return false }
            }
            
            // Validate password if changing
            if hasPasswordChange {
                guard passwordsMatch && newPassword.count >= 6 else { return false }
            }
            
            // Validate email format if changing
            if hasEmailChange {
                guard isValidEmail(newEmail) else { return false }
            }
            
            return true
        }
        
        init(user: User, email: String) {
            self.user = user
            self.email = email
            self.displayName = user.displayName
            self.username = user.username
            self.newEmail = email
        }
        
        private func isValidEmail(_ email: String) -> Bool {
            let emailRegex = #"^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
            return email.range(of: emailRegex, options: .regularExpression) != nil
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
        case onAppear
        case checkUsernameAvailability
        case usernameAvailabilityResult(Bool)
        case saveTapped
        case profileUpdateResult(Result<User, Error>)
        case emailUpdateResult(Result<Void, Error>)
        case passwordUpdateResult(Result<Void, Error>)
        case dismiss
        case delegate(Delegate)
        
        @CasePathable
        enum Delegate: Equatable {
            case profileUpdated(User)
        }
    }
    
    @Dependency(\.profileClient) var profileClient
    @Dependency(\.authClient) var authClient
    @Dependency(\.dismiss) var dismiss
    
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
                
                // Don't check if same as current or invalid format
                guard state.username != state.user.username, state.isUsernameFormatValid else {
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
                
            case .onAppear:
                return .none
                
            case .checkUsernameAvailability:
                guard !state.username.isEmpty else { return .none }
                guard state.username != state.user.username else { return .none }
                
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
                
            case .saveTapped:
                state.isSaving = true
                state.errorMessage = nil
                state.successMessage = nil
                
                let hasProfileChanges = state.hasProfileChanges
                let hasEmailChange = state.hasEmailChange
                let hasPasswordChange = state.hasPasswordChange
                
                let displayName = state.displayName
                let username = state.username
                let originalUsername = state.user.username
                let newEmail = state.newEmail
                let newPassword = state.newPassword
                
                return .run { send in
                    // Update profile (display name and/or username)
                    if hasProfileChanges {
                        do {
                            var updatedUser: User
                            
                            // Update display name
                            updatedUser = try await profileClient.updateProfile(displayName, nil)
                            
                            // Update username if changed
                            if username != originalUsername {
                                updatedUser = try await profileClient.updateUsername(username)
                            }
                            
                            await send(.profileUpdateResult(.success(updatedUser)))
                        } catch {
                            await send(.profileUpdateResult(.failure(error)))
                            return
                        }
                    }
                    
                    // Update email
                    if hasEmailChange {
                        do {
                            try await authClient.updateEmail(newEmail)
                            await send(.emailUpdateResult(.success(())))
                        } catch {
                            await send(.emailUpdateResult(.failure(error)))
                            return
                        }
                    }
                    
                    // Update password
                    if hasPasswordChange {
                        do {
                            try await authClient.updatePassword(newPassword)
                            await send(.passwordUpdateResult(.success(())))
                        } catch {
                            await send(.passwordUpdateResult(.failure(error)))
                            return
                        }
                    }
                    
                    // If only email/password changed without profile changes
                    if !hasProfileChanges && (hasEmailChange || hasPasswordChange) {
                        let currentUser = try await profileClient.getCurrentUserProfile()
                        await send(.profileUpdateResult(.success(currentUser)))
                    }
                }
                
            case .profileUpdateResult(.success(let user)):
                state.isSaving = false
                state.user = user
                state.successMessage = "Profile updated successfully"
                return .merge(
                    .send(.delegate(.profileUpdated(user))),
                    .run { _ in
                        try await Task.sleep(for: .seconds(1))
                    }.concatenate(with: .send(.dismiss))
                )
                
            case .profileUpdateResult(.failure(let error)):
                state.isSaving = false
                state.errorMessage = error.localizedDescription
                return .none
                
            case .emailUpdateResult(.success):
                state.successMessage = "Email updated. Check your inbox to confirm."
                return .none
                
            case .emailUpdateResult(.failure(let error)):
                state.isSaving = false
                state.errorMessage = "Failed to update email: \(error.localizedDescription)"
                return .none
                
            case .passwordUpdateResult(.success):
                state.currentPassword = ""
                state.newPassword = ""
                state.confirmPassword = ""
                state.successMessage = "Password updated successfully"
                return .none
                
            case .passwordUpdateResult(.failure(let error)):
                state.isSaving = false
                state.errorMessage = "Failed to update password: \(error.localizedDescription)"
                return .none
                
            case .dismiss:
                return .run { _ in await dismiss() }
                
            case .delegate:
                return .none
            }
        }
    }
}
