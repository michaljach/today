import ComposableArchitecture
import SwiftUI

struct CommentsView: View {
    @Bindable var store: StoreOf<CommentsFeature>
    @FocusState private var isInputFocused: Bool
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Comments list
                commentsListView
                
                Divider()
                
                // Input bar
                commentInputBar
            }
            .navigationTitle("Comments")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                store.send(.onAppear)
            }
        }
    }
    
    private var commentsListView: some View {
        Group {
            if store.isLoading && store.comments.isEmpty {
                VStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
            } else if store.comments.isEmpty {
                VStack {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "bubble.left.and.bubble.right")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)
                        Text("No comments yet")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                        Text("Be the first to comment!")
                            .font(.subheadline)
                            .foregroundStyle(.tertiary)
                    }
                    Spacer()
                }
            } else {
                List {
                    ForEach(store.comments) { comment in
                        CommentRowView(
                            comment: comment,
                            isOwnComment: comment.userId == store.currentUserId,
                            onUserTapped: { user in
                                store.send(.userTapped(user))
                            }
                        )
                        .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                        .listRowSeparator(.hidden)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            if comment.userId == store.currentUserId {
                                Button(role: .destructive) {
                                    store.send(.deleteComment(comment))
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
    }
    
    private var commentInputBar: some View {
        HStack(spacing: 12) {
            TextField("Add a comment...", text: $store.newCommentText, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...4)
                .focused($isInputFocused)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 20))
            
            Button {
                store.send(.submitComment)
                isInputFocused = false
            } label: {
                Group {
                    if store.isSubmitting {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "arrow.up")
                            .fontWeight(.semibold)
                    }
                }
                .frame(width: 32, height: 32)
                .background(canSubmit ? Color.accentColor : Color.gray.opacity(0.5))
                .clipShape(Circle())
                .foregroundStyle(.white)
            }
            .disabled(!canSubmit || store.isSubmitting)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
    }
    
    private var canSubmit: Bool {
        !store.newCommentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

struct CommentRowView: View {
    let comment: Comment
    var isOwnComment: Bool = false
    var onUserTapped: ((User) -> Void)?
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Avatar
            Button {
                if let user = comment.user {
                    onUserTapped?(user)
                }
            } label: {
                AvatarView(url: comment.user?.avatarURL, size: 36)
            }
            .buttonStyle(.plain)
            
            VStack(alignment: .leading, spacing: 4) {
                // User name and time
                HStack(spacing: 6) {
                    Button {
                        if let user = comment.user {
                            onUserTapped?(user)
                        }
                    } label: {
                        Text(comment.user?.displayName ?? "Unknown")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    .buttonStyle(.plain)
                    
                    Text("@\(comment.user?.username ?? "unknown")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Text("·")
                        .foregroundStyle(.secondary)
                    
                    Text(comment.createdAt?.timeAgoDisplay() ?? "")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                // Comment content
                Text(comment.content)
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer(minLength: 0)
        }
    }
}

#Preview("With Comments") {
    CommentsView(
        store: Store(
            initialState: CommentsFeature.State(
                post: Post.mockPosts[0],
                comments: IdentifiedArrayOf(uniqueElements: Comment.mockComments),
                currentUserId: Comment.mockComments[0].userId
            )
        ) {
            CommentsFeature()
        }
    )
}

#Preview("Empty") {
    CommentsView(
        store: Store(
            initialState: CommentsFeature.State(
                post: Post.mockPosts[0]
            )
        ) {
            CommentsFeature()
        }
    )
}

#Preview("Loading") {
    CommentsView(
        store: Store(
            initialState: CommentsFeature.State(
                post: Post.mockPosts[0],
                isLoading: true
            )
        ) {
            CommentsFeature()
        }
    )
}
