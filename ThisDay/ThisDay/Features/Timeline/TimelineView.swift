import ComposableArchitecture
import SwiftUI

struct TimelineView: View {
    @Bindable var store: StoreOf<TimelineFeature>
    var canPostToday: Bool = true
    var lastPostDate: Date?
    var onComposeTapped: (() -> Void)?
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                Group {
                    if store.isLoading && store.posts.isEmpty {
                        ProgressView("Loading...")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if let errorMessage = store.errorMessage, store.posts.isEmpty {
                        ContentUnavailableView {
                            Label("Error", systemImage: "exclamationmark.triangle")
                        } description: {
                            Text(errorMessage)
                        } actions: {
                            Button("Retry") {
                                store.send(.onAppear)
                            }
                        }
                    } else if store.posts.isEmpty {
                        ContentUnavailableView {
                            Label("No Posts", systemImage: "photo.on.rectangle.angled")
                        } description: {
                            Text("Be the first to share a moment!")
                        } actions: {
                            if canPostToday, let onComposeTapped {
                                Button("Create Post") {
                                    onComposeTapped()
                                }
                                .buttonStyle(.borderedProminent)
                            }
                        }
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 24) {
                                // Add spacing for floating banner
                                if !canPostToday {
                                    Color.clear.frame(height: 36)
                                }
                                
                            ForEach(store.posts) { post in
                                PostView(
                                    post: post,
                                    currentUserId: store.currentUserId,
                                    onProfileTapped: { user in
                                        store.send(.profileTapped(user))
                                    },
                                    onDeleteTapped: { post in
                                        store.send(.deletePostTapped(post))
                                    },
                                    onLikeTapped: { post in
                                        store.send(.likeTapped(post))
                                    },
                                    onCommentsTapped: { post in
                                        store.send(.commentsTapped(post))
                                    }
                                )
                                .onAppear {
                                    // Load more when reaching the last few posts
                                    if post.id == store.posts.suffix(3).first?.id {
                                        store.send(.loadMore)
                                    }
                                }
                            }
                                
                                if store.hasMorePosts && !store.posts.isEmpty {
                                    ProgressView()
                                        .padding()
                                }
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 16)
                        }
                        .refreshable {
                            await store.send(.refresh).finish()
                        }
                    }
                }
                
                // Floating countdown banner at top
                if !canPostToday, let lastPostDate {
                    CountdownTimerView(lastPostDate: lastPostDate, style: .floating)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(item: $store.scope(state: \.destination?.profile, action: \.destination.profile)) { profileStore in
                ProfileView(store: profileStore)
            }
            .sheet(item: $store.scope(state: \.destination?.comments, action: \.destination.comments)) { commentsStore in
                CommentsView(store: commentsStore)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
            .toolbar {
                if canPostToday {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            onComposeTapped?()
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
            .alert(
                "Delete Post",
                isPresented: Binding(
                    get: { store.postToDelete != nil },
                    set: { if !$0 { store.send(.cancelDelete) } }
                )
            ) {
                Button("Cancel", role: .cancel) {
                    store.send(.cancelDelete)
                }
                Button("Delete", role: .destructive) {
                    store.send(.confirmDelete)
                }
            } message: {
                Text("Are you sure you want to delete this post? This action cannot be undone.")
            }
        }
        .onAppear {
            store.send(.onAppear)
        }
    }
}

#Preview("Can post") {
    TimelineView(
        store: Store(initialState: TimelineFeature.State()) {
            TimelineFeature()
        } withDependencies: {
            $0.postClient = .previewValue
            $0.authClient = .previewValue
        },
        canPostToday: true,
        onComposeTapped: {}
    )
}

#Preview("Already posted today") {
    TimelineView(
        store: Store(initialState: TimelineFeature.State()) {
            TimelineFeature()
        } withDependencies: {
            $0.postClient = .previewValue
            $0.authClient = .previewValue
        },
        canPostToday: false,
        lastPostDate: Date().addingTimeInterval(-3600),
        onComposeTapped: {}
    )
}
