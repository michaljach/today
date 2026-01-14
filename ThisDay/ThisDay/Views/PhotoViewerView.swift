import ComposableArchitecture
import SwiftUI

struct PhotoViewerView: View {
    let post: Post
    @Binding var selectedIndex: Int
    var onUserTapped: ((User) -> Void)?
    var showInlineComments: Bool = false
    @Environment(\.dismiss) private var dismiss
    
    @State private var commentsStore: StoreOf<CommentsFeature>?
    @State private var showCommentsSheet: Bool = false
    
    private var currentPhoto: Photo? {
        guard selectedIndex < post.photos.count else { return nil }
        return post.photos[selectedIndex]
    }
    
    var body: some View {
        Group {
            if showInlineComments {
                inlineCommentsLayout
            } else {
                fullscreenLayout
            }
        }
        .background(Color.black)
        .onAppear {
            if showInlineComments && commentsStore == nil {
                commentsStore = Store(
                    initialState: CommentsFeature.State(post: post)
                ) {
                    CommentsFeature()
                }
                commentsStore?.send(.onAppear)
            }
        }
    }
    
    // MARK: - Inline Comments Layout
    
    private var inlineCommentsLayout: some View {
        VStack(spacing: 0) {
            // User header at top
            userHeaderOverlay
                .padding(.top, 16)
                .padding(.bottom, 12)
            
            // Photo carousel - below header
            TabView(selection: $selectedIndex) {
                ForEach(post.photos.indices, id: \.self) { index in
                    PhotoPageView(photo: post.photos[index])
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: post.photos.count > 1 ? .automatic : .never))
            
            Spacer(minLength: 0)
        }
        .safeAreaInset(edge: .bottom) {
            if let store = commentsStore {
                CommentsBottomBar(
                    store: store,
                    onTap: { showCommentsSheet = true }
                )
            }
        }
        .sheet(isPresented: $showCommentsSheet) {
            if let store = commentsStore {
                CommentsSheetView(
                    store: store,
                    onUserTapped: onUserTapped
                )
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
        }
    }
    
    private var userHeaderOverlay: some View {
        HStack(spacing: 12) {
            Button {
                if let user = post.user {
                    onUserTapped?(user)
                }
            } label: {
                AvatarView(url: post.user?.avatarURL, size: 36)
            }
            .buttonStyle(.plain)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(post.user?.displayName ?? "Unknown")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                Text("@\(post.user?.username ?? "unknown")")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
            }
            .contentShape(Rectangle())
            .onTapGesture {
                if let user = post.user {
                    onUserTapped?(user)
                }
            }
            
            Spacer()
            
            // Close button
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 30, height: 30)
                    .background(.white.opacity(0.2))
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, 16)
    }
    
    // MARK: - Original Fullscreen Layout
    
    private var fullscreenLayout: some View {
        ZStack {
            TabView(selection: $selectedIndex) {
                ForEach(post.photos.indices, id: \.self) { index in
                    PhotoPageView(photo: post.photos[index])
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            
            VStack {
                headerView
                Spacer()
                footerView
            }
        }
    }
    
    private var headerView: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                AvatarView(url: post.user?.avatarURL, size: 40)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(post.user?.displayName ?? "Unknown")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                    Text("@\(post.user?.username ?? "unknown")")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                }
                
                Spacer()
            }
            .contentShape(Rectangle())
            .onTapGesture {
                if let user = post.user {
                    onUserTapped?(user)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(
            LinearGradient(
                colors: [.black.opacity(0.7), .black.opacity(0)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .padding(.top, 44)
    }
    
    private var footerView: some View {
        VStack(spacing: 12) {
            if post.photos.count > 1 {
                Text("\(selectedIndex + 1) / \(post.photos.count)")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.black.opacity(0.6))
                    .clipShape(Capsule())
            }
            
            if let takenAt = currentPhoto?.takenAt {
                HStack(spacing: 6) {
                    Image(systemName: "camera")
                        .font(.caption)
                    Text(takenAt, style: .time)
                        .font(.subheadline)
                    Text("·")
                    Text(takenAt, style: .date)
                        .font(.subheadline)
                }
                .foregroundStyle(.white.opacity(0.9))
            }
            
            HStack(spacing: 24) {
                HStack(spacing: 6) {
                    Image(systemName: post.isLikedByCurrentUser ? "heart.fill" : "heart")
                        .foregroundStyle(post.isLikedByCurrentUser ? .red : .white)
                    Text("\(post.likesCount)")
                        .foregroundStyle(.white)
                }
                .font(.subheadline)
                
                HStack(spacing: 6) {
                    Image(systemName: "bubble.right")
                    Text("\(post.commentsCount)")
                }
                .font(.subheadline)
                .foregroundStyle(.white)
                
                Spacer()
            }
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 16)
        .padding(.bottom, 24)
        .background(
            LinearGradient(
                colors: [.black.opacity(0), .black.opacity(0.7)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
}

// MARK: - Comments Bottom Bar

private struct CommentsBottomBar: View {
    @Bindable var store: StoreOf<CommentsFeature>
    var onTap: () -> Void
    
    @FocusState private var isInputFocused: Bool
    
    private var previewComments: [Comment] {
        Array(store.comments.prefix(2))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Only show preview when keyboard is not focused
            if !isInputFocused {
                // Header with like and comment buttons
                HStack(spacing: 20) {
                    // Like button - separate tap target
                    Button {
                        store.send(.likeTapped)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: store.isLikedByCurrentUser ? "heart.fill" : "heart")
                                .foregroundStyle(store.isLikedByCurrentUser ? .red : .primary)
                            Text("\(store.likesCount)")
                        }
                        .font(.subheadline)
                    }
                    .buttonStyle(.plain)
                    
                    // Comments count
                    HStack(spacing: 6) {
                        Image(systemName: "bubble.right")
                        Text("\(store.comments.count)")
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    // Expand indicator
                    Image(systemName: "chevron.up")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                
                Divider()
                
                // Tappable area (comments preview)
                Button(action: onTap) {
                    VStack(alignment: .leading, spacing: 0) {
                        if store.isLoading && store.comments.isEmpty {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Spacer()
                            }
                            .padding(12)
                        } else if store.comments.isEmpty {
                            Text("No comments yet")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .padding(12)
                        } else {
                            ForEach(previewComments) { comment in
                                CommentRow(comment: comment, onUserTapped: nil)
                            }
                            .padding(.top, 8)
                            
                            // Show more button - left aligned
                            Text(store.comments.count > 2 ? "Show all \(store.comments.count) comments" : "Show comments")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundStyle(.blue)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            
            // Comment input
            commentInputBar
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 8)
        .background(Color(.systemBackground))
        .animation(.easeInOut(duration: 0.2), value: isInputFocused)
    }
    
    private var commentInputBar: some View {
        HStack(spacing: 10) {
            Group {
                if #available(iOS 26.0, *) {
                    TextField("Add a comment...", text: $store.newCommentText)
                        .textFieldStyle(.plain)
                        .font(.subheadline)
                        .focused($isInputFocused)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .glassEffect()
                } else {
                    TextField("Add a comment...", text: $store.newCommentText)
                        .textFieldStyle(.plain)
                        .font(.subheadline)
                        .focused($isInputFocused)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                }
            }
            .onSubmit {
                if canSubmit {
                    store.send(.submitComment)
                }
            }
            
            if isInputFocused {
                Button {
                    isInputFocused = false
                } label: {
                    Text("Cancel")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            
            Button {
                store.send(.submitComment)
                isInputFocused = false
            } label: {
                Group {
                    if store.isSubmitting {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title2)
                    }
                }
                .foregroundStyle(canSubmit ? .blue : .gray)
            }
            .disabled(!canSubmit || store.isSubmitting)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
    
    private var canSubmit: Bool {
        !store.newCommentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

// MARK: - Comments Sheet View

private struct CommentsSheetView: View {
    @Bindable var store: StoreOf<CommentsFeature>
    var onUserTapped: ((User) -> Void)?
    @FocusState private var isInputFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with stats
            sheetHeader
            
            Divider()
            
            // Comments list
            commentsListView
            
            Divider()
            
            // Input bar
            commentInputBar
        }
    }
    
    private var sheetHeader: some View {
        HStack(spacing: 20) {
            // Like button
            Button {
                store.send(.likeTapped)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: store.isLikedByCurrentUser ? "heart.fill" : "heart")
                        .foregroundStyle(store.isLikedByCurrentUser ? .red : .primary)
                    Text("\(store.likesCount)")
                }
                .font(.subheadline)
            }
            .buttonStyle(.plain)
            
            // Comments count
            HStack(spacing: 6) {
                Image(systemName: "bubble.right")
                Text("\(store.comments.count) comments")
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 12)
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
                    VStack(spacing: 8) {
                        Image(systemName: "bubble.left.and.bubble.right")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                        Text("No comments yet")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text("Be the first to comment")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    Spacer()
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(store.comments) { comment in
                            CommentRow(
                                comment: comment,
                                onUserTapped: onUserTapped
                            )
                        }
                    }
                }
            }
        }
    }
    
    private var commentInputBar: some View {
        HStack(spacing: 10) {
            TextField("Add a comment...", text: $store.newCommentText)
                .textFieldStyle(.plain)
                .font(.subheadline)
                .focused($isInputFocused)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .onSubmit {
                    if canSubmit {
                        store.send(.submitComment)
                    }
                }
            
            Button {
                store.send(.submitComment)
                isInputFocused = false
            } label: {
                Group {
                    if store.isSubmitting {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title2)
                    }
                }
                .foregroundStyle(canSubmit ? .blue : .gray)
            }
            .disabled(!canSubmit || store.isSubmitting)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
    
    private var canSubmit: Bool {
        !store.newCommentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

// MARK: - Comment Row

private struct CommentRow: View {
    let comment: Comment
    var onUserTapped: ((User) -> Void)?
    
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Button {
                if let user = comment.user {
                    onUserTapped?(user)
                }
            } label: {
                AvatarView(url: comment.user?.avatarURL, size: 32)
            }
            .buttonStyle(.plain)
            
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(comment.user?.displayName ?? "Unknown")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    Text(comment.createdAt?.timeAgoDisplay() ?? "")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Text(comment.content)
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }
}

// MARK: - Photo Page View

struct PhotoPageView: View {
    let photo: Photo
    
    @State private var scale: CGFloat = 1.0
    
    var body: some View {
        AsyncImage(url: photo.url) { phase in
            switch phase {
            case .empty:
                ProgressView()
                    .tint(.white)
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .scaleEffect(scale)
                    .gesture(
                        MagnificationGesture()
                            .onChanged { value in
                                scale = max(1, min(value, 4))
                            }
                            .onEnded { _ in
                                withAnimation(.easeOut(duration: 0.2)) {
                                    scale = 1
                                }
                            }
                    )
                    .onTapGesture(count: 2) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            scale = scale > 1 ? 1 : 2.5
                        }
                    }
            case .failure:
                VStack(spacing: 8) {
                    Image(systemName: "photo")
                        .font(.largeTitle)
                        .foregroundStyle(.gray)
                    Text("Failed to load")
                        .font(.caption)
                        .foregroundStyle(.gray)
                }
            @unknown default:
                EmptyView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview("Fullscreen") {
    PhotoViewerView(
        post: Post.mockPosts[0],
        selectedIndex: .constant(0),
        showInlineComments: false
    )
    .presentationBackground(.black)
}

#Preview("With Inline Comments") {
    PhotoViewerView(
        post: Post.mockPosts[0],
        selectedIndex: .constant(0),
        showInlineComments: true
    )
    .presentationBackground(.black)
}
