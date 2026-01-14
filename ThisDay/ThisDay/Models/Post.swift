import Foundation

struct Post: Equatable, Identifiable, Codable {
    let id: UUID
    let userId: UUID
    let caption: String?
    var likesCount: Int
    let commentsCount: Int
    let createdAt: Date
    let updatedAt: Date?
    
    // Non-database properties for UI convenience (not decoded from API)
    var user: User?
    var photos: [Photo]
    var isLikedByCurrentUser: Bool
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case caption
        case likesCount = "likes_count"
        case commentsCount = "comments_count"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    init(
        id: UUID = UUID(),
        userId: UUID,
        caption: String? = nil,
        likesCount: Int = 0,
        commentsCount: Int = 0,
        createdAt: Date = Date(),
        updatedAt: Date? = nil,
        user: User? = nil,
        photos: [Photo] = [],
        isLikedByCurrentUser: Bool = false
    ) {
        self.id = id
        self.userId = userId
        self.caption = caption
        self.likesCount = likesCount
        self.commentsCount = commentsCount
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.user = user
        self.photos = photos
        self.isLikedByCurrentUser = isLikedByCurrentUser
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        userId = try container.decode(UUID.self, forKey: .userId)
        caption = try container.decodeIfPresent(String.self, forKey: .caption)
        likesCount = try container.decodeIfPresent(Int.self, forKey: .likesCount) ?? 0
        commentsCount = try container.decodeIfPresent(Int.self, forKey: .commentsCount) ?? 0
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)
        // These are populated separately, not from the API response
        user = nil
        photos = []
        isLikedByCurrentUser = false
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(userId, forKey: .userId)
        try container.encodeIfPresent(caption, forKey: .caption)
        try container.encode(likesCount, forKey: .likesCount)
        try container.encode(commentsCount, forKey: .commentsCount)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(updatedAt, forKey: .updatedAt)
    }
}

// MARK: - Like model
struct Like: Codable, Equatable {
    let id: UUID
    let userId: UUID
    let postId: UUID
    let createdAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case postId = "post_id"
        case createdAt = "created_at"
    }
}

struct CreateLikeDTO: Codable {
    let userId: UUID
    let postId: UUID
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case postId = "post_id"
    }
}

// MARK: - Comment model
struct Comment: Codable, Equatable, Identifiable {
    let id: UUID
    let userId: UUID
    let postId: UUID
    let content: String
    let createdAt: Date?
    
    // UI convenience property (not from DB)
    var user: User?
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case postId = "post_id"
        case content
        case createdAt = "created_at"
    }
    
    init(
        id: UUID = UUID(),
        userId: UUID,
        postId: UUID,
        content: String,
        createdAt: Date? = nil,
        user: User? = nil
    ) {
        self.id = id
        self.userId = userId
        self.postId = postId
        self.content = content
        self.createdAt = createdAt
        self.user = user
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        userId = try container.decode(UUID.self, forKey: .userId)
        postId = try container.decode(UUID.self, forKey: .postId)
        content = try container.decode(String.self, forKey: .content)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
        user = nil
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(userId, forKey: .userId)
        try container.encode(postId, forKey: .postId)
        try container.encode(content, forKey: .content)
        try container.encodeIfPresent(createdAt, forKey: .createdAt)
    }
}

struct CreateCommentDTO: Codable {
    let userId: UUID
    let postId: UUID
    let content: String
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case postId = "post_id"
        case content
    }
}

// MARK: - DTO for creating posts (without id, timestamps, counts)
struct CreatePostDTO: Codable {
    let userId: UUID
    let caption: String?
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case caption
    }
}

// MARK: - Mock Data
extension Post {
    static let mockPosts: [Post] = [
        Post(
            userId: User.mock1.id,
            caption: "Beautiful day out!",
            likesCount: 42,
            commentsCount: 5,
            user: .mock1,
            photos: [
                .mock(index: 1),
                .mock(index: 2),
                .mock(index: 3),
                .mock(index: 4)
            ]
        ),
        Post(
            userId: User.mock2.id,
            caption: "Solo shot",
            likesCount: 128,
            commentsCount: 12,
            user: .mock2,
            photos: [
                .mock(index: 5)
            ]
        ),
        Post(
            userId: User.mock3.id,
            caption: "Photo dump from my latest shoot",
            likesCount: 256,
            commentsCount: 34,
            user: .mock3,
            photos: [
                .mock(index: 6),
                .mock(index: 7),
                .mock(index: 8),
                .mock(index: 9),
                .mock(index: 10),
                .mock(index: 11)
            ]
        ),
        Post(
            userId: User.mock4.id,
            caption: "Travel memories",
            likesCount: 89,
            commentsCount: 8,
            user: .mock4,
            photos: [
                .mock(index: 12),
                .mock(index: 13)
            ]
        ),
        Post(
            userId: User.mock1.id,
            caption: "Weekend vibes",
            likesCount: 67,
            commentsCount: 3,
            user: .mock1,
            photos: [
                .mock(index: 14),
                .mock(index: 15),
                .mock(index: 16)
            ]
        ),
        Post(
            userId: User.mock2.id,
            caption: "Collection of favorites",
            likesCount: 203,
            commentsCount: 21,
            user: .mock2,
            photos: [
                .mock(index: 17),
                .mock(index: 18),
                .mock(index: 19),
                .mock(index: 20),
                .mock(index: 21)
            ]
        )
    ]
}

// MARK: - Comment Mock Data
extension Comment {
    static let mockComments: [Comment] = [
        Comment(
            userId: User.mock1.id,
            postId: UUID(),
            content: "This is amazing! Love the composition.",
            createdAt: Date().addingTimeInterval(-3600),
            user: .mock1
        ),
        Comment(
            userId: User.mock2.id,
            postId: UUID(),
            content: "Beautiful shot!",
            createdAt: Date().addingTimeInterval(-1800),
            user: .mock2
        ),
        Comment(
            userId: User.mock3.id,
            postId: UUID(),
            content: "Where was this taken?",
            createdAt: Date().addingTimeInterval(-900),
            user: .mock3
        ),
        Comment(
            userId: User.mock4.id,
            postId: UUID(),
            content: "Wow, stunning!",
            createdAt: Date().addingTimeInterval(-300),
            user: .mock4
        )
    ]
}
