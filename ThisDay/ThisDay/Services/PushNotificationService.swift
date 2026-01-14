import Foundation
import UserNotifications
import UIKit

/// Service for handling push notifications with APNs
actor PushNotificationService {
    static let shared = PushNotificationService()
    
    private init() {}
    
    // MARK: - Permission & Registration
    
    /// Requests permission for push notifications
    /// - Returns: Whether permission was granted
    func requestPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            
            if granted {
                await MainActor.run {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
            
            return granted
        } catch {
            print("Push notification permission error: \(error)")
            return false
        }
    }
    
    /// Checks current notification authorization status
    func getAuthorizationStatus() async -> UNAuthorizationStatus {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return settings.authorizationStatus
    }
    
    /// Registers device token with Supabase
    /// - Parameter deviceToken: The APNs device token
    func registerDeviceToken(_ deviceToken: Data) async {
        let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        
        guard let userId = await AuthService.shared.currentUserId() else {
            print("Cannot register device token: user not authenticated")
            return
        }
        
        do {
            // Upsert the device token to the push_tokens table
            try await supabase
                .from("push_tokens")
                .upsert([
                    "user_id": userId.uuidString,
                    "token": tokenString,
                    "platform": "ios",
                    "updated_at": ISO8601DateFormatter().string(from: Date())
                ], onConflict: "user_id, token")
                .execute()
            
            print("Device token registered successfully")
        } catch {
            print("Failed to register device token: \(error)")
        }
    }
    
    /// Unregisters device token when user signs out
    func unregisterDeviceToken(_ deviceToken: Data) async {
        let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        
        do {
            try await supabase
                .from("push_tokens")
                .delete()
                .eq("token", value: tokenString)
                .execute()
            
            print("Device token unregistered successfully")
        } catch {
            print("Failed to unregister device token: \(error)")
        }
    }
    
    /// Removes all device tokens for current user (useful on sign out)
    func removeAllTokensForCurrentUser() async {
        guard let userId = await AuthService.shared.currentUserId() else {
            return
        }
        
        do {
            try await supabase
                .from("push_tokens")
                .delete()
                .eq("user_id", value: userId)
                .execute()
            
            print("All device tokens removed for user")
        } catch {
            print("Failed to remove device tokens: \(error)")
        }
    }
    
    // MARK: - Badge Management
    
    /// Updates the app badge count
    func setBadgeCount(_ count: Int) async {
        await MainActor.run {
            UIApplication.shared.applicationIconBadgeNumber = count
        }
    }
    
    /// Clears the app badge
    func clearBadge() async {
        await setBadgeCount(0)
    }
}

// MARK: - Push Notification Payload

/// Represents a push notification payload
struct PushNotificationPayload {
    let title: String
    let body: String
    let type: AppNotification.NotificationType
    let postId: UUID?
    let actorId: UUID?
    
    init?(userInfo: [AnyHashable: Any]) {
        guard let aps = userInfo["aps"] as? [String: Any],
              let alert = aps["alert"] as? [String: Any],
              let title = alert["title"] as? String,
              let body = alert["body"] as? String else {
            return nil
        }
        
        self.title = title
        self.body = body
        
        // Parse custom data
        if let typeString = userInfo["type"] as? String {
            self.type = AppNotification.NotificationType(rawValue: typeString) ?? .like
        } else {
            self.type = .like
        }
        
        if let postIdString = userInfo["post_id"] as? String {
            self.postId = UUID(uuidString: postIdString)
        } else {
            self.postId = nil
        }
        
        if let actorIdString = userInfo["actor_id"] as? String {
            self.actorId = UUID(uuidString: actorIdString)
        } else {
            self.actorId = nil
        }
    }
}
