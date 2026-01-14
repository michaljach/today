import Foundation
import Supabase

/// Service for handling authentication operations with Supabase Auth
actor AuthService {
    static let shared = AuthService()
    
    private init() {}
    
    // MARK: - Sign Up
    
    /// Creates a new user account with email and password
    /// - Parameters:
    ///   - email: User's email address
    ///   - password: User's password (minimum 6 characters)
    ///   - username: Unique username for the profile
    ///   - displayName: Display name for the profile
    /// - Returns: The created User session
    /// - Note: The database trigger `on_auth_user_created` automatically creates a profile entry
    func signUp(
        email: String,
        password: String,
        username: String,
        displayName: String
    ) async throws -> Session {
        let response = try await supabase.auth.signUp(
            email: email,
            password: password,
            data: [
                "username": .string(username),
                "display_name": .string(displayName)
            ]
        )
        
        guard let session = response.session else {
            throw AuthError.signUpFailed("No session returned. Email confirmation may be required.")
        }
        
        return session
    }
    
    // MARK: - Sign In
    
    /// Signs in a user with email and password
    /// - Parameters:
    ///   - email: User's email address
    ///   - password: User's password
    /// - Returns: The user session
    func signIn(email: String, password: String) async throws -> Session {
        try await supabase.auth.signIn(
            email: email,
            password: password
        )
    }
    
    // MARK: - Sign Out
    
    /// Signs out the current user
    func signOut() async throws {
        try await supabase.auth.signOut()
    }
    
    // MARK: - Session Management
    
    /// Gets the current session if available
    /// - Returns: The current session or nil if not signed in
    func currentSession() async -> Session? {
        try? await supabase.auth.session
    }
    
    /// Gets the current user if signed in
    /// - Returns: The current Supabase user or nil
    func currentUser() async -> Supabase.User? {
        try? await supabase.auth.session.user
    }
    
    /// Gets the current user's ID if signed in
    /// - Returns: The user's UUID or nil
    func currentUserId() async -> UUID? {
        try? await supabase.auth.session.user.id
    }
    
    /// Refreshes the current session
    /// - Returns: The refreshed session
    func refreshSession() async throws -> Session {
        try await supabase.auth.refreshSession()
    }
    
    // MARK: - Password Reset
    
    /// Sends a password reset email to the specified address
    /// - Parameter email: The email address to send the reset link to
    func resetPassword(email: String) async throws {
        try await supabase.auth.resetPasswordForEmail(email)
    }
    
    /// Updates the user's password (requires authenticated session)
    /// - Parameter newPassword: The new password to set
    func updatePassword(newPassword: String) async throws {
        try await supabase.auth.update(user: UserAttributes(password: newPassword))
    }
    
    // MARK: - Auth State
    
    /// Stream of authentication state changes
    func authStateChanges() -> AsyncStream<AuthChangeEvent> {
        AsyncStream { continuation in
            Task {
                for await (event, _) in supabase.auth.authStateChanges {
                    continuation.yield(event)
                }
                continuation.finish()
            }
        }
    }
}

// MARK: - Auth Errors

enum AuthError: LocalizedError {
    case signUpFailed(String)
    case signInFailed(String)
    case notAuthenticated
    case sessionExpired
    
    var errorDescription: String? {
        switch self {
        case .signUpFailed(let message):
            return "Sign up failed: \(message)"
        case .signInFailed(let message):
            return "Sign in failed: \(message)"
        case .notAuthenticated:
            return "User is not authenticated"
        case .sessionExpired:
            return "Session has expired. Please sign in again."
        }
    }
}
