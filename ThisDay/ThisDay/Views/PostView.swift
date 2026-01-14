import ComposableArchitecture
import SwiftUI

struct AvatarView: View {
  let url: URL?
  var size: CGFloat = 44
  
  var body: some View {
    Group {
      if let url {
        AsyncImage(url: url) { phase in
          switch phase {
          case .empty:
            placeholderCircle
              .overlay {
                ProgressView()
                  .scaleEffect(0.5)
              }
          case .success(let image):
            image
              .resizable()
              .aspectRatio(contentMode: .fill)
          case .failure:
            placeholderCircle
              .overlay {
                Image(systemName: "person.fill")
                  .font(.system(size: size * 0.4))
                  .foregroundStyle(.gray)
              }
          @unknown default:
            placeholderCircle
          }
        }
      } else {
        placeholderCircle
          .overlay {
            Image(systemName: "person.fill")
              .font(.system(size: size * 0.4))
              .foregroundStyle(.gray)
          }
      }
    }
    .frame(width: size, height: size)
    .clipShape(Circle())
  }
  
  private var placeholderCircle: some View {
    Circle()
      .fill(Color.gray.opacity(0.3))
  }
}

struct PostView: View {
  let post: Post
  var currentUserId: UUID?
  var onProfileTapped: ((User) -> Void)?
  var onDeleteTapped: ((Post) -> Void)?
  var onLikeTapped: ((Post) -> Void)?
  var onCommentsTapped: ((Post) -> Void)?
  
  @State private var showPhotoViewer = false
  @State private var selectedPhotoIndex: Int = 0
  
  private var isOwnPost: Bool {
    guard let currentUserId else { return false }
    return post.userId == currentUserId
  }
  
  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      // User header
      if let user = post.user {
        UserHeaderView(
          user: user,
          createdAt: post.createdAt,
          isOwnPost: isOwnPost,
          onProfileTapped: onProfileTapped,
          onDeleteTapped: isOwnPost ? { onDeleteTapped?(post) } : nil
        )
      }
      
      // Caption
      if let caption = post.caption, !caption.isEmpty {
        Text(caption)
          .font(.subheadline)
      }
      
      // Photo grid
      PhotoGridView(photos: post.photos) { index in
        selectedPhotoIndex = index
        showPhotoViewer = true
      }
      
      // Engagement stats
      HStack(spacing: 20) {
        Button {
          onLikeTapped?(post)
        } label: {
          Label("\(post.likesCount)", systemImage: post.isLikedByCurrentUser ? "heart.fill" : "heart")
            .foregroundStyle(post.isLikedByCurrentUser ? .red : .secondary)
        }
        .buttonStyle(.plain)
        
        Button {
          onCommentsTapped?(post)
        } label: {
          Label("\(post.commentsCount)", systemImage: "bubble.right")
            .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        
        Spacer()
        
        Image(systemName: "square.and.arrow.up")
          .foregroundStyle(.secondary)
      }
      .font(.subheadline)
    }
    .sheet(isPresented: $showPhotoViewer) {
      PhotoViewerView(
        store: Store(
          initialState: PhotoViewerFeature.State(
            post: post,
            selectedIndex: selectedPhotoIndex,
            showInlineComments: true
          )
        ) {
          PhotoViewerFeature()
        }
      )
      .presentationBackground(.black)
      .presentationDragIndicator(.visible)
    }
  }
}

struct UserHeaderView: View {
  let user: User
  let createdAt: Date
  var isOwnPost: Bool = false
  var onProfileTapped: ((User) -> Void)?
  var onDeleteTapped: (() -> Void)?
  
  var body: some View {
    HStack(spacing: 10) {
      // Avatar
      Button {
        onProfileTapped?(user)
      } label: {
        AvatarView(url: user.avatarURL, size: 44)
      }
      .buttonStyle(.plain)
      
      // User info
      Button {
        onProfileTapped?(user)
      } label: {
        VStack(alignment: .leading, spacing: 2) {
          Text(user.displayName)
            .font(.body)
            .fontWeight(.semibold)
          
          Text("@\(user.username)")
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
      }
      .buttonStyle(.plain)
      
      Spacer()
      
      // Time ago
      Text(createdAt.timeAgoDisplay())
        .font(.caption)
        .foregroundStyle(.secondary)
      
      // Three-dots menu (only for own posts)
      if isOwnPost {
        Menu {
          Button(role: .destructive) {
            onDeleteTapped?()
          } label: {
            Label("Delete Post", systemImage: "trash")
          }
        } label: {
          Image(systemName: "ellipsis")
            .font(.body)
            .foregroundStyle(.foreground)
            .frame(width: 32, height: 32)
            .contentShape(Rectangle())
        }
      }
    }
  }
}

extension Date {
  func timeAgoDisplay() -> String {
    let formatter = RelativeDateTimeFormatter()
    formatter.unitsStyle = .abbreviated
    return formatter.localizedString(for: self, relativeTo: Date())
  }
}

#Preview {
  ScrollView {
    LazyVStack(spacing: 0) {
      // Show one post as "own post" with delete menu
      PostView(
        post: Post.mockPosts[0],
        currentUserId: Post.mockPosts[0].userId
      )
      // Show others as regular posts (no menu)
      PostView(post: Post.mockPosts[1])
      PostView(post: Post.mockPosts[2])
    }
  }
}
