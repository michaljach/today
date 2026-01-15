import Foundation

/// User profile model matching the Supabase `profiles` table
/// Maps to: profiles(id, username, display_name, avatar_url, created_at, updated_at)
struct User: Equatable, Identifiable, Codable {
    let id: UUID
    let username: String
    let displayName: String
    let avatarURL: URL?
    let createdAt: Date?
    let updatedAt: Date?
    
    // Stats - populated separately, not from profiles table
    var postsCount: Int?
    var followersCount: Int?
    var followingCount: Int?
    
    init(
        id: UUID = UUID(),
        username: String,
        displayName: String,
        avatarURL: URL? = nil,
        createdAt: Date? = nil,
        updatedAt: Date? = nil,
        postsCount: Int? = nil,
        followersCount: Int? = nil,
        followingCount: Int? = nil
    ) {
        self.id = id
        self.username = username
        self.displayName = displayName
        self.avatarURL = avatarURL
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.postsCount = postsCount
        self.followersCount = followersCount
        self.followingCount = followingCount
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case username
        case displayName = "display_name"
        case avatarURL = "avatar_url"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case postsCount = "posts_count"
        case followersCount = "followers_count"
        case followingCount = "following_count"
    }
}

extension User {
    static let mock1 = User(
        username: "johndoe",
        displayName: "John Doe",
        avatarURL: URL(string: "https://i.pravatar.cc/150?u=johndoe")
    )
    
    static let mock2 = User(
        username: "janedoe",
        displayName: "Jane Doe",
        avatarURL: URL(string: "https://i.pravatar.cc/150?u=janedoe")
    )
    
    static let mock3 = User(
        username: "photographer",
        displayName: "Photo Master",
        avatarURL: URL(string: "https://i.pravatar.cc/150?u=photographer")
    )
    
    static let mock4 = User(
        username: "traveler",
        displayName: "World Traveler",
        avatarURL: URL(string: "https://i.pravatar.cc/150?u=traveler")
    )
}
