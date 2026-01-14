import ComposableArchitecture
import SwiftUI

@main
struct ThisDayApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    static let store = Store(initialState: AppFeature.State()) {
        AppFeature()
    }
    
    var body: some Scene {
        WindowGroup {
            AppView(store: Self.store)
                .onReceive(NotificationCenter.default.publisher(for: .pushNotificationTapped)) { notification in
                    handlePushNotificationTap(notification)
                }
        }
    }
    
    private func handlePushNotificationTap(_ notification: Notification) {
        guard let userInfo = notification.userInfo else { return }
        
        let type = userInfo["type"] as? String ?? ""
        let postId = userInfo["postId"] as? UUID
        let actorId = userInfo["actorId"] as? UUID
        
        Self.store.send(.pushNotificationTapped(type: type, postId: postId, actorId: actorId))
    }
}
