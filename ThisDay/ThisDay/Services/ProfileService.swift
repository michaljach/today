import Foundation
import Supabase

/// Service for handling profile/user CRUD operations with Supabase
actor ProfileService {
    static let shared = ProfileService()
    
    private let tableName = "profiles"
    
    private init() {}
    
    // MARK: - Read Operations
    
    /// Fetches a profile by user ID
    /// - Parameter userId: The UUID of the user
    /// - Returns: The User profile
    func getProfile(userId: UUID) async throws -> User {
        try await supabase
            .from(tableName)
            .select()
            .eq("id", value: userId)
            .single()
            .execute()
            .value
    }
    
    /// Fetches a profile by username
    /// - Parameter username: The unique username
    /// - Returns: The User profile
    func getProfile(username: String) async throws -> User {
        try await supabase
            .from(tableName)
            .select()
            .eq("username", value: username)
            .single()
            .execute()
            .value
    }
    
    /// Fetches multiple profiles by user IDs
    /// - Parameter userIds: Array of user UUIDs
    /// - Returns: Array of User profiles
    func getProfiles(userIds: [UUID]) async throws -> [User] {
        guard !userIds.isEmpty else { return [] }
        
        let ids = userIds.map { $0.uuidString }
        return try await supabase
            .from(tableName)
            .select()
            .in("id", values: ids)
            .execute()
            .value
    }
    
    /// Fetches the current authenticated user's profile
    /// - Returns: The current user's profile
    func getCurrentUserProfile() async throws -> User {
        guard let userId = await AuthService.shared.currentUserId() else {
            throw ProfileError.notAuthenticated
        }
        return try await getProfile(userId: userId)
    }
    
    /// Searches for profiles by username or display name
    /// - Parameters:
    ///   - query: The search query
    ///   - limit: Maximum number of results (default 20)
    /// - Returns: Array of matching profiles
    func searchProfiles(query: String, limit: Int = 20) async throws -> [User] {
        try await supabase
            .from(tableName)
            .select()
            .or("username.ilike.%\(query)%,display_name.ilike.%\(query)%")
            .limit(limit)
            .execute()
            .value
    }
    
    /// Fetches all users (for explore/discovery)
    /// - Parameter limit: Maximum number of results (default 20)
    /// - Returns: Array of user profiles ordered by most recent
    func getAllUsers(limit: Int = 20) async throws -> [User] {
        try await supabase
            .from(tableName)
            .select()
            .order("created_at", ascending: false)
            .limit(limit)
            .execute()
            .value
    }
    
    // MARK: - Update Operations
    
    /// Updates the current user's profile
    /// - Parameters:
    ///   - displayName: New display name (optional)
    ///   - avatarURL: New avatar URL (optional)
    /// - Returns: The updated User profile
    @discardableResult
    func updateCurrentUserProfile(
        displayName: String? = nil,
        avatarURL: URL? = nil
    ) async throws -> User {
        guard let userId = await AuthService.shared.currentUserId() else {
            throw ProfileError.notAuthenticated
        }
        
        var updates: [String: AnyJSON] = [
            "updated_at": .string(ISO8601DateFormatter().string(from: Date()))
        ]
        
        if let displayName = displayName {
            updates["display_name"] = .string(displayName)
        }
        
        if let avatarURL = avatarURL {
            updates["avatar_url"] = .string(avatarURL.absoluteString)
        }
        
        return try await supabase
            .from(tableName)
            .update(updates)
            .eq("id", value: userId)
            .select()
            .single()
            .execute()
            .value
    }
    
    /// Updates the username for the current user
    /// - Parameter username: New unique username
    /// - Returns: The updated User profile
    /// - Note: This will fail if the username is already taken
    @discardableResult
    func updateUsername(_ username: String) async throws -> User {
        guard let userId = await AuthService.shared.currentUserId() else {
            throw ProfileError.notAuthenticated
        }
        
        let updates: [String: AnyJSON] = [
            "username": .string(username),
            "updated_at": .string(ISO8601DateFormatter().string(from: Date()))
        ]
        
        return try await supabase
            .from(tableName)
            .update(updates)
            .eq("id", value: userId)
            .select()
            .single()
            .execute()
            .value
    }
    
    // MARK: - Check Availability
    
    /// Checks if a username is available
    /// - Parameter username: The username to check
    /// - Returns: True if the username is available
    func isUsernameAvailable(_ username: String) async throws -> Bool {
        let result: [User] = try await supabase
            .from(tableName)
            .select("id")
            .eq("username", value: username)
            .execute()
            .value
        
        return result.isEmpty
    }
}

// MARK: - Profile Errors

enum ProfileError: LocalizedError {
    case notAuthenticated
    case profileNotFound
    case usernameTaken
    case updateFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "User is not authenticated"
        case .profileNotFound:
            return "Profile not found"
        case .usernameTaken:
            return "This username is already taken"
        case .updateFailed(let message):
            return "Profile update failed: \(message)"
        }
    }
}
