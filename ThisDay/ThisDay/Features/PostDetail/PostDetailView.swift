import ComposableArchitecture
import SwiftUI

struct PostDetailView: View {
    @Bindable var store: StoreOf<PostDetailFeature>
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                PostView(
                    post: store.post,
                    currentUserId: store.currentUserId,
                    onProfileTapped: { user in
                        store.send(.profileTapped(user))
                    },
                    onDeleteTapped: nil, // Don't allow deletion from notification view
                    onLikeTapped: { _ in
                        store.send(.likeTapped)
                    },
                    onCommentsTapped: { _ in
                        store.send(.commentsTapped)
                    }
                )
            }
            .padding()
        }
        .navigationTitle("Post")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $store.scope(state: \.destination?.profile, action: \.destination.profile)) { profileStore in
            ProfileView(store: profileStore)
        }
        .sheet(item: $store.scope(state: \.destination?.comments, action: \.destination.comments)) { commentsStore in
            CommentsView(store: commentsStore)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .onAppear {
            store.send(.onAppear)
        }
    }
}

#Preview {
    NavigationStack {
        PostDetailView(
            store: Store(initialState: PostDetailFeature.State(post: Post.mockPosts[0])) {
                PostDetailFeature()
            } withDependencies: {
                $0.postClient = .previewValue
                $0.authClient = .previewValue
            }
        )
    }
}
