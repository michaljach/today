import Foundation
import Supabase

/// Service for handling follow relationships with Supabase
actor FollowService {
    static let shared = FollowService()
    
    private let tableName = "follows"
    
    private init() {}
    
    // MARK: - Follow Operations
    
    /// Follows a user
    /// - Parameter userId: The UUID of the user to follow
    func follow(userId: UUID) async throws {
        guard let currentUserId = await AuthService.shared.currentUserId() else {
            throw FollowError.notAuthenticated
        }
        
        guard currentUserId != userId else {
            throw FollowError.cannotFollowSelf
        }
        
        let followDTO = CreateFollowDTO(followerId: currentUserId, followingId: userId)
        
        try await supabase
            .from(tableName)
            .insert(followDTO)
            .execute()
    }
    
    /// Unfollows a user
    /// - Parameter userId: The UUID of the user to unfollow
    func unfollow(userId: UUID) async throws {
        guard let currentUserId = await AuthService.shared.currentUserId() else {
            throw FollowError.notAuthenticated
        }
        
        try await supabase
            .from(tableName)
            .delete()
            .eq("follower_id", value: currentUserId)
            .eq("following_id", value: userId)
            .execute()
    }
    
    /// Toggles follow status for a user
    /// - Parameter userId: The UUID of the user
    /// - Returns: True if now following, false if unfollowed
    @discardableResult
    func toggleFollow(userId: UUID) async throws -> Bool {
        let isCurrentlyFollowing = try await isFollowing(userId: userId)
        
        if isCurrentlyFollowing {
            try await unfollow(userId: userId)
            return false
        } else {
            try await follow(userId: userId)
            return true
        }
    }
    
    // MARK: - Query Operations
    
    /// Checks if the current user is following a specific user
    /// - Parameter userId: The UUID of the user to check
    /// - Returns: True if currently following
    func isFollowing(userId: UUID) async throws -> Bool {
        guard let currentUserId = await AuthService.shared.currentUserId() else {
            return false
        }
        
        struct FollowResult: Decodable {
            let followingId: UUID
            
            enum CodingKeys: String, CodingKey {
                case followingId = "following_id"
            }
        }
        
        let result: [FollowResult] = try await supabase
            .from(tableName)
            .select("following_id")
            .eq("follower_id", value: currentUserId)
            .eq("following_id", value: userId)
            .execute()
            .value
        
        return !result.isEmpty
    }
    
    /// Gets the list of user IDs that the current user is following
    /// - Returns: Array of user UUIDs
    func getFollowingIds() async throws -> [UUID] {
        guard let currentUserId = await AuthService.shared.currentUserId() else {
            return []
        }
        
        struct FollowResult: Decodable {
            let followingId: UUID
            
            enum CodingKeys: String, CodingKey {
                case followingId = "following_id"
            }
        }
        
        let result: [FollowResult] = try await supabase
            .from(tableName)
            .select("following_id")
            .eq("follower_id", value: currentUserId)
            .execute()
            .value
        
        return result.map { $0.followingId }
    }
    
    /// Gets the list of users that the current user is following
    /// - Returns: Array of User profiles with stats
    func getFollowing() async throws -> [User] {
        let followingIds = try await getFollowingIds()
        guard !followingIds.isEmpty else { return [] }
        
        return try await ProfileService.shared.getProfilesWithStats(userIds: followingIds)
    }
    
    /// Gets the list of user IDs who follow the current user
    /// - Returns: Array of user UUIDs
    func getFollowerIds() async throws -> [UUID] {
        guard let currentUserId = await AuthService.shared.currentUserId() else {
            return []
        }
        
        struct FollowResult: Decodable {
            let followerId: UUID
            
            enum CodingKeys: String, CodingKey {
                case followerId = "follower_id"
            }
        }
        
        let result: [FollowResult] = try await supabase
            .from(tableName)
            .select("follower_id")
            .eq("following_id", value: currentUserId)
            .execute()
            .value
        
        return result.map { $0.followerId }
    }
    
    /// Gets the followers and following counts for a user
    /// - Parameter userId: The UUID of the user
    /// - Returns: Tuple of (followersCount, followingCount)
    func getCounts(userId: UUID) async throws -> (followers: Int, following: Int) {
        struct CountResult: Decodable {
            let count: Int
        }
        
        // Get followers count
        let followersResult: [CountResult] = try await supabase
            .from(tableName)
            .select("*", head: true, count: .exact)
            .eq("following_id", value: userId)
            .execute()
            .value
        
        // Get following count
        let followingResult: [CountResult] = try await supabase
            .from(tableName)
            .select("*", head: true, count: .exact)
            .eq("follower_id", value: userId)
            .execute()
            .value
        
        // Note: Supabase returns count in response headers, so we need different approach
        // For now, fetch and count
        let followers = try await getFollowerCount(userId: userId)
        let following = try await getFollowingCount(userId: userId)
        
        return (followers, following)
    }
    
    /// Gets the number of followers for a user
    func getFollowerCount(userId: UUID) async throws -> Int {
        struct FollowResult: Decodable {
            let followerId: UUID
            
            enum CodingKeys: String, CodingKey {
                case followerId = "follower_id"
            }
        }
        
        let result: [FollowResult] = try await supabase
            .from(tableName)
            .select("follower_id")
            .eq("following_id", value: userId)
            .execute()
            .value
        
        return result.count
    }
    
    /// Gets the number of users a user is following
    func getFollowingCount(userId: UUID) async throws -> Int {
        struct FollowResult: Decodable {
            let followingId: UUID
            
            enum CodingKeys: String, CodingKey {
                case followingId = "following_id"
            }
        }
        
        let result: [FollowResult] = try await supabase
            .from(tableName)
            .select("following_id")
            .eq("follower_id", value: userId)
            .execute()
            .value
        
        return result.count
    }
}

// MARK: - DTOs

private struct CreateFollowDTO: Encodable {
    let followerId: UUID
    let followingId: UUID
    
    enum CodingKeys: String, CodingKey {
        case followerId = "follower_id"
        case followingId = "following_id"
    }
}

// MARK: - Follow Errors

enum FollowError: LocalizedError {
    case notAuthenticated
    case cannotFollowSelf
    case alreadyFollowing
    case notFollowing
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "User is not authenticated"
        case .cannotFollowSelf:
            return "You cannot follow yourself"
        case .alreadyFollowing:
            return "You are already following this user"
        case .notFollowing:
            return "You are not following this user"
        }
    }
}
