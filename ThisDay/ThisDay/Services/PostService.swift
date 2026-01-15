import Foundation
import Supabase

/// Service for handling post CRUD operations with Supabase
actor PostService {
    static let shared = PostService()
    
    private let postsTable = "posts"
    private let photosTable = "photos"
    private let likesTable = "likes"
    private let commentsTable = "comments"
    
    private init() {}
    
    // MARK: - Create Operations
    
    /// Creates a new post with photos
    /// - Parameters:
    ///   - caption: Optional caption for the post
    ///   - photoURLs: Array of photo URLs with optional thumbnail and takenAt date (1-6 photos required)
    /// - Returns: The created Post with photos
    func createPost(
        caption: String?,
        photoURLs: [(url: URL, thumbnailURL: URL?, takenAt: Date?)]
    ) async throws -> Post {
        guard let userId = await AuthService.shared.currentUserId() else {
            throw PostError.notAuthenticated
        }
        
        guard photoURLs.count >= 1 && photoURLs.count <= 6 else {
            throw PostError.invalidPhotoCount
        }
        
        // Create the post
        let createDTO = CreatePostDTO(userId: userId, caption: caption)
        
        var post: Post = try await supabase
            .from(postsTable)
            .insert(createDTO)
            .select()
            .single()
            .execute()
            .value
        
        // Create the photos
        let photoDTOs = photoURLs.enumerated().map { index, photoURL in
            CreatePhotoDTO(
                postId: post.id,
                url: photoURL.url.absoluteString,
                thumbnailURL: photoURL.thumbnailURL?.absoluteString,
                sortOrder: index,
                takenAt: photoURL.takenAt
            )
        }
        
        let photos: [Photo] = try await supabase
            .from(photosTable)
            .insert(photoDTOs)
            .select()
            .execute()
            .value
        
        post.photos = photos.sorted { $0.sortOrder < $1.sortOrder }
        
        return post
    }
    
    // MARK: - Read Operations
    
    /// Fetches a single post by ID with its photos and user
    /// - Parameter postId: The UUID of the post
    /// - Returns: The Post with photos and user populated
    func getPost(postId: UUID) async throws -> Post {
        var post: Post = try await supabase
            .from(postsTable)
            .select()
            .eq("id", value: postId)
            .single()
            .execute()
            .value
        
        // Fetch photos for the post
        let photos: [Photo] = try await supabase
            .from(photosTable)
            .select()
            .eq("post_id", value: postId)
            .order("sort_order")
            .execute()
            .value
        
        post.photos = photos
        
        // Fetch the user profile
        post.user = try await ProfileService.shared.getProfile(userId: post.userId)
        
        return post
    }
    
    /// Fetches the timeline (posts from followed users + own posts, sorted by creation date)
    /// - Parameters:
    ///   - limit: Maximum number of posts to fetch
    ///   - offset: Number of posts to skip (for pagination)
    /// - Returns: Array of Posts with photos and users populated
    func getTimeline(limit: Int = 20, offset: Int = 0) async throws -> [Post] {
        // Get the current user's ID and their followed users
        guard let currentUserId = await AuthService.shared.currentUserId() else {
            throw PostError.notAuthenticated
        }
        
        // Get the list of user IDs we're following
        let followingIds = try await FollowService.shared.getFollowingIds()
        
        // Include current user's posts + followed users' posts
        var userIdsToFetch = followingIds
        userIdsToFetch.append(currentUserId)
        
        // Fetch posts from these users
        var posts: [Post] = try await supabase
            .from(postsTable)
            .select()
            .in("user_id", values: userIdsToFetch.map { $0.uuidString })
            .order("created_at", ascending: false)
            .range(from: offset, to: offset + limit - 1)
            .execute()
            .value
        
        guard !posts.isEmpty else { return [] }
        
        // Collect all post IDs and user IDs
        let postIds = posts.map { $0.id }
        let postUserIds = Array(Set(posts.map { $0.userId }))
        
        // Fetch all photos for these posts in one query
        let allPhotos: [Photo] = try await supabase
            .from(photosTable)
            .select()
            .in("post_id", values: postIds.map { $0.uuidString })
            .order("sort_order")
            .execute()
            .value
        
        // Fetch all users for these posts in one query (with stats for instant profile display)
        let users = try await ProfileService.shared.getProfilesWithStats(userIds: postUserIds)
        let userDict = Dictionary(uniqueKeysWithValues: users.map { ($0.id, $0) })
        
        // Group photos by post ID
        let photosByPostId = Dictionary(grouping: allPhotos) { $0.postId ?? UUID() }
        
        // Get liked posts for current user
        let likedPostIds = try await getLikedPostIds(postIds: postIds)
        
        // Populate posts with photos and users
        for i in posts.indices {
            posts[i].photos = photosByPostId[posts[i].id] ?? []
            posts[i].user = userDict[posts[i].userId]
            posts[i].isLikedByCurrentUser = likedPostIds.contains(posts[i].id)
        }
        
        return posts
    }
    
    /// Fetches the global explore feed (posts from all users, sorted by creation date)
    /// - Parameters:
    ///   - limit: Maximum number of posts to fetch
    ///   - offset: Number of posts to skip (for pagination)
    /// - Returns: Array of Posts with photos and users populated
    func getExploreFeed(limit: Int = 20, offset: Int = 0) async throws -> [Post] {
        var posts: [Post] = try await supabase
            .from(postsTable)
            .select()
            .order("created_at", ascending: false)
            .range(from: offset, to: offset + limit - 1)
            .execute()
            .value
        
        guard !posts.isEmpty else { return [] }
        
        // Collect all post IDs and user IDs
        let postIds = posts.map { $0.id }
        let userIds = Array(Set(posts.map { $0.userId }))
        
        // Fetch all photos for these posts in one query
        let allPhotos: [Photo] = try await supabase
            .from(photosTable)
            .select()
            .in("post_id", values: postIds.map { $0.uuidString })
            .order("sort_order")
            .execute()
            .value
        
        // Fetch all users for these posts in one query (with stats for instant profile display)
        let users = try await ProfileService.shared.getProfilesWithStats(userIds: userIds)
        let userDict = Dictionary(uniqueKeysWithValues: users.map { ($0.id, $0) })
        
        // Group photos by post ID
        let photosByPostId = Dictionary(grouping: allPhotos) { $0.postId ?? UUID() }
        
        // Get liked posts for current user
        let likedPostIds = try await getLikedPostIds(postIds: postIds)
        
        // Populate posts with photos and users
        for i in posts.indices {
            posts[i].photos = photosByPostId[posts[i].id] ?? []
            posts[i].user = userDict[posts[i].userId]
            posts[i].isLikedByCurrentUser = likedPostIds.contains(posts[i].id)
        }
        
        return posts
    }
    
    /// Fetches posts by a specific user
    /// - Parameters:
    ///   - userId: The UUID of the user
    ///   - limit: Maximum number of posts to fetch
    ///   - offset: Number of posts to skip (for pagination)
    /// - Returns: Array of Posts with photos populated
    func getPostsByUser(userId: UUID, limit: Int = 20, offset: Int = 0) async throws -> [Post] {
        var posts: [Post] = try await supabase
            .from(postsTable)
            .select()
            .eq("user_id", value: userId)
            .order("created_at", ascending: false)
            .range(from: offset, to: offset + limit - 1)
            .execute()
            .value
        
        guard !posts.isEmpty else { return [] }
        
        // Fetch all photos for these posts
        let postIds = posts.map { $0.id }
        let allPhotos: [Photo] = try await supabase
            .from(photosTable)
            .select()
            .in("post_id", values: postIds.map { $0.uuidString })
            .order("sort_order")
            .execute()
            .value
        
        // Fetch the user once
        let user = try await ProfileService.shared.getProfile(userId: userId)
        
        // Group photos by post ID
        let photosByPostId = Dictionary(grouping: allPhotos) { $0.postId ?? UUID() }
        
        // Get liked posts for current user
        let likedPostIds = try await getLikedPostIds(postIds: postIds)
        
        // Populate posts
        for i in posts.indices {
            posts[i].photos = photosByPostId[posts[i].id] ?? []
            posts[i].user = user
            posts[i].isLikedByCurrentUser = likedPostIds.contains(posts[i].id)
        }
        
        return posts
    }
    
    /// Fetches posts for the current user
    /// - Parameters:
    ///   - limit: Maximum number of posts to fetch
    ///   - offset: Number of posts to skip
    /// - Returns: Array of the current user's posts
    func getCurrentUserPosts(limit: Int = 20, offset: Int = 0) async throws -> [Post] {
        guard let userId = await AuthService.shared.currentUserId() else {
            throw PostError.notAuthenticated
        }
        return try await getPostsByUser(userId: userId, limit: limit, offset: offset)
    }
    
    /// Gets the date of the current user's last post
    /// - Returns: The creation date of the most recent post, or nil if no posts exist
    func getLastPostDate() async throws -> Date? {
        guard let userId = await AuthService.shared.currentUserId() else {
            throw PostError.notAuthenticated
        }
        
        // Use a lightweight struct to decode just the created_at field
        struct PostDate: Decodable {
            let createdAt: Date
            
            enum CodingKeys: String, CodingKey {
                case createdAt = "created_at"
            }
        }
        
        let posts: [PostDate] = try await supabase
            .from(postsTable)
            .select("created_at")
            .eq("user_id", value: userId)
            .order("created_at", ascending: false)
            .limit(1)
            .execute()
            .value
        
        return posts.first?.createdAt
    }
    
    // MARK: - Update Operations
    
    /// Updates a post's caption
    /// - Parameters:
    ///   - postId: The UUID of the post to update
    ///   - caption: The new caption
    /// - Returns: The updated Post
    @discardableResult
    func updateCaption(postId: UUID, caption: String?) async throws -> Post {
        guard let userId = await AuthService.shared.currentUserId() else {
            throw PostError.notAuthenticated
        }
        
        let updates: [String: AnyJSON] = [
            "caption": caption.map { .string($0) } ?? .null,
            "updated_at": .string(ISO8601DateFormatter().string(from: Date()))
        ]
        
        let post: Post = try await supabase
            .from(postsTable)
            .update(updates)
            .eq("id", value: postId)
            .eq("user_id", value: userId) // Ensure user owns the post
            .select()
            .single()
            .execute()
            .value
        
        return post
    }
    
    // MARK: - Delete Operations
    
    /// Deletes a post and its associated photos
    /// - Parameter postId: The UUID of the post to delete
    /// - Note: Photos are deleted automatically via CASCADE
    func deletePost(postId: UUID) async throws {
        guard let userId = await AuthService.shared.currentUserId() else {
            throw PostError.notAuthenticated
        }
        
        try await supabase
            .from(postsTable)
            .delete()
            .eq("id", value: postId)
            .eq("user_id", value: userId) // Ensure user owns the post
            .execute()
    }
    
    // MARK: - Like Operations
    
    /// Checks if the current user has liked specific posts
    /// - Parameter postIds: Array of post UUIDs to check
    /// - Returns: Set of post IDs that the current user has liked
    func getLikedPostIds(postIds: [UUID]) async throws -> Set<UUID> {
        guard let userId = await AuthService.shared.currentUserId() else {
            return []
        }
        
        guard !postIds.isEmpty else { return [] }
        
        struct LikeResult: Decodable {
            let postId: UUID
            
            enum CodingKeys: String, CodingKey {
                case postId = "post_id"
            }
        }
        
        let likes: [LikeResult] = try await supabase
            .from(likesTable)
            .select("post_id")
            .eq("user_id", value: userId)
            .in("post_id", values: postIds.map { $0.uuidString })
            .execute()
            .value
        
        return Set(likes.map { $0.postId })
    }
    
    /// Likes a post
    /// - Parameter postId: The UUID of the post to like
    func likePost(postId: UUID) async throws {
        guard let userId = await AuthService.shared.currentUserId() else {
            throw PostError.notAuthenticated
        }
        
        let likeDTO = CreateLikeDTO(userId: userId, postId: postId)
        
        try await supabase
            .from(likesTable)
            .insert(likeDTO)
            .execute()
    }
    
    /// Unlikes a post
    /// - Parameter postId: The UUID of the post to unlike
    func unlikePost(postId: UUID) async throws {
        guard let userId = await AuthService.shared.currentUserId() else {
            throw PostError.notAuthenticated
        }
        
        try await supabase
            .from(likesTable)
            .delete()
            .eq("user_id", value: userId)
            .eq("post_id", value: postId)
            .execute()
    }
    
    /// Toggles like status for a post
    /// - Parameter postId: The UUID of the post
    /// - Returns: True if now liked, false if now unliked
    @discardableResult
    func toggleLike(postId: UUID) async throws -> Bool {
        guard let userId = await AuthService.shared.currentUserId() else {
            throw PostError.notAuthenticated
        }
        
        // Check if already liked
        let likedPostIds = try await getLikedPostIds(postIds: [postId])
        let isCurrentlyLiked = likedPostIds.contains(postId)
        
        if isCurrentlyLiked {
            try await unlikePost(postId: postId)
            return false
        } else {
            try await likePost(postId: postId)
            return true
        }
    }
    
    /// Increments the like count for a post
    /// - Parameter postId: The UUID of the post
    /// - Note: In production, you'd want a separate likes table and RPC for this
    func incrementLikeCount(postId: UUID) async throws {
        // This is a simplified version. In production, use a separate likes table
        // and a database function to handle this atomically
        try await supabase.rpc("increment_likes", params: ["post_id": postId.uuidString]).execute()
    }
    
    /// Decrements the like count for a post
    /// - Parameter postId: The UUID of the post
    func decrementLikeCount(postId: UUID) async throws {
        try await supabase.rpc("decrement_likes", params: ["post_id": postId.uuidString]).execute()
    }
    
    // MARK: - Comment Operations
    
    /// Fetches comments for a post
    /// - Parameters:
    ///   - postId: The UUID of the post
    ///   - limit: Maximum number of comments to fetch
    ///   - offset: Number of comments to skip (for pagination)
    /// - Returns: Array of Comments with user populated
    func getComments(postId: UUID, limit: Int = 50, offset: Int = 0) async throws -> [Comment] {
        var comments: [Comment] = try await supabase
            .from(commentsTable)
            .select()
            .eq("post_id", value: postId)
            .order("created_at", ascending: true)
            .range(from: offset, to: offset + limit - 1)
            .execute()
            .value
        
        guard !comments.isEmpty else { return [] }
        
        // Fetch all users for these comments
        let userIds = Array(Set(comments.map { $0.userId }))
        let users = try await ProfileService.shared.getProfiles(userIds: userIds)
        let userDict = Dictionary(uniqueKeysWithValues: users.map { ($0.id, $0) })
        
        // Populate comments with users
        for i in comments.indices {
            comments[i].user = userDict[comments[i].userId]
        }
        
        return comments
    }
    
    /// Creates a new comment on a post
    /// - Parameters:
    ///   - postId: The UUID of the post to comment on
    ///   - content: The comment text
    /// - Returns: The created Comment with user populated
    func createComment(postId: UUID, content: String) async throws -> Comment {
        guard let userId = await AuthService.shared.currentUserId() else {
            throw PostError.notAuthenticated
        }
        
        let createDTO = CreateCommentDTO(userId: userId, postId: postId, content: content)
        
        var comment: Comment = try await supabase
            .from(commentsTable)
            .insert(createDTO)
            .select()
            .single()
            .execute()
            .value
        
        // Fetch the user for this comment
        comment.user = try await ProfileService.shared.getProfile(userId: userId)
        
        return comment
    }
    
    /// Deletes a comment
    /// - Parameter commentId: The UUID of the comment to delete
    func deleteComment(commentId: UUID) async throws {
        guard let userId = await AuthService.shared.currentUserId() else {
            throw PostError.notAuthenticated
        }
        
        try await supabase
            .from(commentsTable)
            .delete()
            .eq("id", value: commentId)
            .eq("user_id", value: userId) // Ensure user owns the comment
            .execute()
    }
}

// MARK: - Post Errors

enum PostError: LocalizedError {
    case notAuthenticated
    case postNotFound
    case invalidPhotoCount
    case notAuthorized
    case deleteFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "User is not authenticated"
        case .postNotFound:
            return "Post not found"
        case .invalidPhotoCount:
            return "Posts must have between 1 and 6 photos"
        case .notAuthorized:
            return "You are not authorized to perform this action"
        case .deleteFailed(let message):
            return "Failed to delete post: \(message)"
        }
    }
}
