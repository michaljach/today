import Foundation
import Supabase
import Realtime

/// Model for notifications stored in the database
struct AppNotification: Codable, Identifiable, Equatable {
    let id: UUID
    let recipientId: UUID
    let actorId: UUID
    let type: String
    let postId: UUID?
    let commentId: UUID?
    var isRead: Bool
    let createdAt: Date
    
    // Populated after fetch
    var actor: User?
    
    enum CodingKeys: String, CodingKey {
        case id
        case recipientId = "recipient_id"
        case actorId = "actor_id"
        case type
        case postId = "post_id"
        case commentId = "comment_id"
        case isRead = "is_read"
        case createdAt = "created_at"
    }
    
    var notificationType: NotificationType {
        switch type {
        case "like": return .like
        case "follow": return .follow
        case "comment": return .comment
        default: return .like
        }
    }
    
    enum NotificationType: String, Equatable {
        case like
        case follow
        case comment
    }
}

extension AppNotification {
    static let mock1 = AppNotification(
        id: UUID(),
        recipientId: User.mock1.id,
        actorId: User.mock2.id,
        type: "like",
        postId: UUID(),
        commentId: nil,
        isRead: false,
        createdAt: Date().addingTimeInterval(-300),
        actor: .mock2
    )
    
    static let mock2 = AppNotification(
        id: UUID(),
        recipientId: User.mock1.id,
        actorId: User.mock3.id,
        type: "follow",
        postId: nil,
        commentId: nil,
        isRead: false,
        createdAt: Date().addingTimeInterval(-3600),
        actor: .mock3
    )
    
    static let mock3 = AppNotification(
        id: UUID(),
        recipientId: User.mock1.id,
        actorId: User.mock4.id,
        type: "comment",
        postId: UUID(),
        commentId: UUID(),
        isRead: true,
        createdAt: Date().addingTimeInterval(-7200),
        actor: .mock4
    )
    
    static let mockNotifications: [AppNotification] = [mock1, mock2, mock3]
}

/// Service for handling notifications with Supabase including realtime
actor NotificationService {
    static let shared = NotificationService()
    
    private let tableName = "notifications"
    private var realtimeChannel: RealtimeChannelV2?
    
    private init() {}
    
    // MARK: - Fetch Operations
    
    /// Fetches notifications for the current user
    /// - Parameters:
    ///   - limit: Maximum number of notifications to fetch
    ///   - offset: Number of notifications to skip (for pagination)
    /// - Returns: Array of notifications with actor populated
    func getNotifications(limit: Int = 50, offset: Int = 0) async throws -> [AppNotification] {
        guard let userId = await AuthService.shared.currentUserId() else {
            throw NotificationError.notAuthenticated
        }
        
        var notifications: [AppNotification] = try await supabase
            .from(tableName)
            .select()
            .eq("recipient_id", value: userId)
            .order("created_at", ascending: false)
            .range(from: offset, to: offset + limit - 1)
            .execute()
            .value
        
        guard !notifications.isEmpty else { return [] }
        
        // Fetch all actors for these notifications
        let actorIds = Array(Set(notifications.map { $0.actorId }))
        let actors = try await ProfileService.shared.getProfiles(userIds: actorIds)
        let actorDict = Dictionary(uniqueKeysWithValues: actors.map { ($0.id, $0) })
        
        // Populate notifications with actors
        for i in notifications.indices {
            notifications[i].actor = actorDict[notifications[i].actorId]
        }
        
        return notifications
    }
    
    /// Gets the count of unread notifications
    func getUnreadCount() async throws -> Int {
        guard let userId = await AuthService.shared.currentUserId() else {
            return 0
        }
        
        struct CountResult: Decodable {
            let id: UUID
        }
        
        let result: [CountResult] = try await supabase
            .from(tableName)
            .select("id")
            .eq("recipient_id", value: userId)
            .eq("is_read", value: false)
            .execute()
            .value
        
        return result.count
    }
    
    // MARK: - Update Operations
    
    /// Marks a notification as read
    func markAsRead(notificationId: UUID) async throws {
        guard await AuthService.shared.currentUserId() != nil else {
            throw NotificationError.notAuthenticated
        }
        
        try await supabase
            .from(tableName)
            .update(["is_read": true])
            .eq("id", value: notificationId)
            .execute()
    }
    
    /// Marks all notifications as read for the current user
    func markAllAsRead() async throws {
        guard let userId = await AuthService.shared.currentUserId() else {
            throw NotificationError.notAuthenticated
        }
        
        try await supabase
            .from(tableName)
            .update(["is_read": true])
            .eq("recipient_id", value: userId)
            .eq("is_read", value: false)
            .execute()
    }
    
    // MARK: - Realtime Subscription
    
    /// Subscribes to realtime notifications for the current user
    /// - Returns: AsyncStream of new notifications
    func subscribeToNotifications() async -> AsyncStream<AppNotification> {
        AsyncStream { continuation in
            Task {
                guard let userId = await AuthService.shared.currentUserId() else {
                    continuation.finish()
                    return
                }
                
                // Create a channel for notifications
                let channel = await supabase.realtimeV2.channel("notifications:\(userId.uuidString)")
                
                // Subscribe to INSERT events on the notifications table filtered by recipient_id
                let insertions = await channel.postgresChange(
                    InsertAction.self,
                    schema: "public",
                    table: "notifications",
                    filter: "recipient_id=eq.\(userId.uuidString)"
                )
                
                // Store the channel reference
                await self.setRealtimeChannel(channel)
                
                // Subscribe to the channel
                await channel.subscribe()
                
                // Listen for new notifications
                for await insertion in insertions {
                    do {
                        var notification = try insertion.decodeRecord(as: AppNotification.self, decoder: .iso8601)
                        
                        // Fetch the actor for this notification
                        if let actor = try? await ProfileService.shared.getProfile(userId: notification.actorId) {
                            notification.actor = actor
                        }
                        
                        continuation.yield(notification)
                    } catch {
                        print("Failed to decode notification: \(error)")
                    }
                }
                
                continuation.finish()
            }
        }
    }
    
    /// Unsubscribes from realtime notifications
    func unsubscribe() async {
        if let channel = realtimeChannel {
            await channel.unsubscribe()
            realtimeChannel = nil
        }
    }
    
    private func setRealtimeChannel(_ channel: RealtimeChannelV2) {
        self.realtimeChannel = channel
    }
}

// MARK: - Custom JSON Decoder

extension JSONDecoder {
    static let iso8601: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)
            
            // Try ISO8601 with fractional seconds
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: dateString) {
                return date
            }
            
            // Try without fractional seconds
            formatter.formatOptions = [.withInternetDateTime]
            if let date = formatter.date(from: dateString) {
                return date
            }
            
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date: \(dateString)")
        }
        return decoder
    }()
}

// MARK: - Notification Errors

enum NotificationError: LocalizedError {
    case notAuthenticated
    case notificationNotFound
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "User is not authenticated"
        case .notificationNotFound:
            return "Notification not found"
        }
    }
}
