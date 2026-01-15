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
    
    /// Fetches multiple profiles with their stats (posts, followers, following counts)
    /// - Parameter userIds: Array of user UUIDs
    /// - Returns: Array of User profiles with stats populated
    func getProfilesWithStats(userIds: [UUID]) async throws -> [User] {
        guard !userIds.isEmpty else { return [] }
        
        // First get the basic profiles
        var users = try await getProfiles(userIds: userIds)
        
        // Batch fetch stats for all users
        let stats = try await getStatsForUsers(userIds: userIds)
        
        // Populate stats on users
        for i in users.indices {
            if let userStats = stats[users[i].id] {
                users[i].postsCount = userStats.postsCount
                users[i].followersCount = userStats.followersCount
                users[i].followingCount = userStats.followingCount
            }
        }
        
        return users
    }
    
    /// Batch fetches stats for multiple users
    /// - Parameter userIds: Array of user UUIDs
    /// - Returns: Dictionary mapping user ID to their stats
    private func getStatsForUsers(userIds: [UUID]) async throws -> [UUID: UserStats] {
        guard !userIds.isEmpty else { return [:] }
        
        let ids = userIds.map { $0.uuidString }
        
        // Fetch posts counts
        struct PostCount: Decodable {
            let userId: UUID
            
            enum CodingKeys: String, CodingKey {
                case userId = "user_id"
            }
        }
        
        let posts: [PostCount] = try await supabase
            .from("posts")
            .select("user_id")
            .in("user_id", values: ids)
            .execute()
            .value
        
        // Count posts per user
        var postsCounts: [UUID: Int] = [:]
        for post in posts {
            postsCounts[post.userId, default: 0] += 1
        }
        
        // Fetch followers counts (where user is being followed)
        struct FollowerCount: Decodable {
            let followingId: UUID
            
            enum CodingKeys: String, CodingKey {
                case followingId = "following_id"
            }
        }
        
        let followers: [FollowerCount] = try await supabase
            .from("follows")
            .select("following_id")
            .in("following_id", values: ids)
            .execute()
            .value
        
        // Count followers per user
        var followersCounts: [UUID: Int] = [:]
        for follow in followers {
            followersCounts[follow.followingId, default: 0] += 1
        }
        
        // Fetch following counts (where user is following others)
        struct FollowingCount: Decodable {
            let followerId: UUID
            
            enum CodingKeys: String, CodingKey {
                case followerId = "follower_id"
            }
        }
        
        let following: [FollowingCount] = try await supabase
            .from("follows")
            .select("follower_id")
            .in("follower_id", values: ids)
            .execute()
            .value
        
        // Count following per user
        var followingCounts: [UUID: Int] = [:]
        for follow in following {
            followingCounts[follow.followerId, default: 0] += 1
        }
        
        // Build stats dictionary
        var stats: [UUID: UserStats] = [:]
        for userId in userIds {
            stats[userId] = UserStats(
                postsCount: postsCounts[userId] ?? 0,
                followersCount: followersCounts[userId] ?? 0,
                followingCount: followingCounts[userId] ?? 0
            )
        }
        
        return stats
    }
    
    struct UserStats {
        let postsCount: Int
        let followersCount: Int
        let followingCount: Int
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
