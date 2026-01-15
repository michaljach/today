import ComposableArchitecture
import SwiftUI

struct PhotoViewerView: View {
    @Bindable var store: StoreOf<PhotoViewerFeature>
    @Environment(\.dismiss) private var dismiss
    var onUserTapped: ((User) -> Void)?
    
    var body: some View {
        Group {
            if store.showInlineComments {
                inlineCommentsLayout
            } else {
                fullscreenLayout
            }
        }
        .background(Color.black)
        .onAppear {
            store.send(.onAppear)
        }
    }
    
    // MARK: - Inline Comments Layout
    
    private var inlineCommentsLayout: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Photo carousel
                TabView(selection: $store.selectedIndex) {
                    ForEach(store.post.photos.indices, id: \.self) { index in
                        PhotoPageView(photo: store.post.photos[index])
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: store.post.photos.count > 1 ? .automatic : .never))
                
                Spacer(minLength: 0)
            }
            .scrollDismissesKeyboard(.interactively)
            .onTapGesture {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }
            .safeAreaInset(edge: .bottom) {
                if let commentsStore = store.scope(state: \.comments, action: \.comments) {
                    CommentsBottomBar(
                        store: commentsStore,
                        onTap: { store.send(.showCommentsSheet) }
                    )
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        if let user = store.post.user {
                            store.send(.userTapped(user))
                            onUserTapped?(user)
                        }
                    } label: {
                        HStack(spacing: 8) {
                            AvatarView(url: store.post.user?.avatarURL, size: 28)
                            VStack(alignment: .leading, spacing: 0) {
                                Text(store.post.user?.displayName ?? "Unknown")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                Text("@\(store.post.user?.username ?? "unknown")")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.horizontal, 4)
                        .contentShape(.capsule)
                    }
                    .buttonStyle(.plain)
                    .fixedSize()
                    .padding(.trailing, 8)
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.body)
                            .fontWeight(.semibold)
                    }
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .sheet(isPresented: $store.showCommentsSheet) {
            if let commentsStore = store.scope(state: \.comments, action: \.comments) {
                CommentsSheetView(
                    store: commentsStore,
                    onUserTapped: { user in
                        store.send(.userTapped(user))
                    }
                )
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
        }
    }
    
    // MARK: - Original Fullscreen Layout
    
    private var fullscreenLayout: some View {
        ZStack {
            TabView(selection: $store.selectedIndex) {
                ForEach(store.post.photos.indices, id: \.self) { index in
                    PhotoPageView(photo: store.post.photos[index])
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
                AvatarView(url: store.post.user?.avatarURL, size: 40)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(store.post.user?.displayName ?? "Unknown")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                    Text("@\(store.post.user?.username ?? "unknown")")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                }
                
                Spacer()
            }
            .contentShape(Rectangle())
            .onTapGesture {
                if let user = store.post.user {
                    store.send(.userTapped(user))
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
            if store.post.photos.count > 1 {
                Text("\(store.selectedIndex + 1) / \(store.post.photos.count)")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.black.opacity(0.6))
                    .clipShape(Capsule())
            }
            
            if let takenAt = store.currentPhoto?.takenAt {
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
                    Image(systemName: store.post.isLikedByCurrentUser ? "heart.fill" : "heart")
                        .foregroundStyle(store.post.isLikedByCurrentUser ? .red : .white)
                    Text("\(store.post.likesCount)")
                        .foregroundStyle(.white)
                }
                .font(.subheadline)
                
                HStack(spacing: 6) {
                    Image(systemName: "bubble.right")
                    Text("\(store.post.commentsCount)")
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
                                .foregroundStyle(store.isLikedByCurrentUser ? .red : .white)
                            Text("\(store.likesCount)")
                                .foregroundStyle(.white)
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
                    .foregroundStyle(.white.opacity(0.7))
                    
                    Spacer()
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
                                .foregroundStyle(.white.opacity(0.7))
                                .padding(12)
                        } else {
                            ForEach(previewComments) { comment in
                                CommentRow(comment: comment, onUserTapped: nil, isDarkBackground: true)
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
        .background(Color.clear)
        .animation(.easeInOut(duration: 0.2), value: isInputFocused)
    }
    
    private var commentInputBar: some View {
        HStack(spacing: 10) {
            Group {
                if #available(iOS 26.0, *) {
                    TextField("Add a comment...", text: $store.newCommentText)
                        .textFieldStyle(.plain)
                        .font(.subheadline)
                        .foregroundStyle(.white)
                        .focused($isInputFocused)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .glassEffect()
                } else {
                    TextField("Add a comment...", text: $store.newCommentText)
                        .textFieldStyle(.plain)
                        .font(.subheadline)
                        .foregroundStyle(.white)
                        .focused($isInputFocused)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color.white.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                }
            }
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
                            .tint(.white)
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
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Divider()
                
                // Comments list
                commentsListView
                
                Divider()
                
                // Input bar
                commentInputBar
            }
            .navigationTitle("Comments")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.body)
                            .fontWeight(.semibold)
                    }
                }
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
                    LazyVStack(spacing: 12) {
                        ForEach(store.comments) { comment in
                            CommentRow(
                                comment: comment,
                                onUserTapped: onUserTapped
                            )
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
        }
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
    var isDarkBackground: Bool = false
    
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
                        .foregroundStyle(isDarkBackground ? .white : .primary)
                    
                    Text(comment.createdAt?.timeAgoDisplay() ?? "")
                        .font(.caption)
                        .foregroundStyle(isDarkBackground ? .white.opacity(0.6) : .secondary)
                }
                
                Text(comment.content)
                    .font(.subheadline)
                    .foregroundStyle(isDarkBackground ? .white : .primary)
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

// MARK: - Previews

#Preview("Fullscreen") {
    PhotoViewerView(
        store: Store(
            initialState: PhotoViewerFeature.State(
                post: Post.mockPosts[0],
                selectedIndex: 0,
                showInlineComments: false
            )
        ) {
            PhotoViewerFeature()
        }
    )
    .presentationBackground(.black)
}

#Preview("With Inline Comments") {
    PhotoViewerView(
        store: Store(
            initialState: PhotoViewerFeature.State(
                post: Post.mockPosts[0],
                selectedIndex: 0,
                showInlineComments: true
            )
        ) {
            PhotoViewerFeature()
        }
    )
    .presentationBackground(.black)
}
