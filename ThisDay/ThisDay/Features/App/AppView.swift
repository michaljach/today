import ComposableArchitecture
import SwiftUI

struct AppView: View {
  @Bindable var store: StoreOf<AppFeature>
  
  var body: some View {
    Group {
      switch store.authState {
      case .loading:
        ProgressView("Loading...")
          .frame(maxWidth: .infinity, maxHeight: .infinity)
        
      case .unauthenticated:
        AuthView(store: store.scope(state: \.auth, action: \.auth))
        
      case .authenticated:
        mainTabView
      }
    }
    .onAppear {
      store.send(.onAppear)
    }
    .sheet(item: $store.scope(state: \.compose, action: \.compose)) { composeStore in
      ComposeView(store: composeStore)
    }
  }
  
  private var mainTabView: some View {
    TabView(selection: $store.selectedTab.sending(\.tabSelected)) {
      TimelineView(
        store: store.scope(state: \.timeline, action: \.timeline),
        canPostToday: store.canPostToday,
        lastPostDate: store.lastPostDate,
        onComposeTapped: { store.send(.composeTapped) }
      )
      .tabItem {
        Image("icon-home")
      }
      .tag(AppFeature.State.Tab.timeline)
      
      ExploreView(
        store: store.scope(state: \.explore, action: \.explore)
      )
      .tabItem {
        Image("icon-search")
      }
      .tag(AppFeature.State.Tab.explore)
      
      NotificationsView(
        store: store.scope(state: \.notifications, action: \.notifications)
      )
      .tabItem {
        Image("icon-notification")
      }
      .tag(AppFeature.State.Tab.notifications)
      .badge(store.unreadNotificationsCount)
      
      NavigationStack {
        ProfileView(
          store: store.scope(state: \.profile, action: \.profile)
        )
      }
      .tabItem {
        Image("icon-user")
      }
      .tag(AppFeature.State.Tab.profile)
    }
  }
}

#Preview("Authenticated") {
  AppView(
    store: Store(
      initialState: AppFeature.State(
        authState: .authenticated(User.mock1.id)
      )
    ) {
      AppFeature()
    } withDependencies: {
      $0.authClient = .previewValue
      $0.profileClient = .previewValue
      $0.postClient = .previewValue
      $0.storageClient = .previewValue
      $0.followClient = .previewValue
      $0.notificationClient = .previewValue
    }
  )
}

#Preview("Unauthenticated") {
  AppView(
    store: Store(
      initialState: AppFeature.State(
        authState: .unauthenticated
      )
    ) {
      AppFeature()
    } withDependencies: {
      $0.authClient = .previewValue
    }
  )
}
