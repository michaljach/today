import ComposableArchitecture
import PhotosUI
import SwiftUI

struct ProfileView: View {
    @Bindable var store: StoreOf<ProfileFeature>
    @State private var selectedPhotoItem: PhotosPickerItem?
    
    var body: some View {
        Group {
            if let errorMessage = store.errorMessage, store.user == nil {
                ContentUnavailableView {
                    Label("Error", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(errorMessage)
                } actions: {
                    Button("Retry") {
                        store.send(.onAppear)
                    }
                }
            } else if let user = store.user {
                ScrollView {
                    VStack(spacing: 20) {
                        profileHeader(user: user)
                        
                        Divider()
                        
                        postsList
                    }
                }
                .refreshable {
                    try? await store.send(.refresh).finish()
                }
            } else {
                ProgressView("Loading...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle(store.isCurrentUser ? "Profile" : store.user?.displayName ?? "Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if store.isCurrentUser {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button(role: .destructive) {
                            store.send(.signOutTapped)
                        } label: {
                            Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                        }
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
        }
        .onAppear {
            store.send(.onAppear)
        }
        .onChange(of: selectedPhotoItem) { _, newItem in
            Task {
                if let newItem,
                   let data = try? await newItem.loadTransferable(type: Data.self) {
                    // Compress and resize the image for avatar
                    if let compressedData = compressImageForAvatar(data: data) {
                        store.send(.avatarSelected(compressedData))
                    }
                }
                selectedPhotoItem = nil
            }
        }
        .sheet(item: $store.scope(state: \.destination?.comments, action: \.destination.comments)) { commentsStore in
            CommentsView(store: commentsStore)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }
    
    private func profileHeader(user: User) -> some View {
        VStack(spacing: 12) {
            if store.isCurrentUser {
                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    avatarView(user: user)
                        .overlay(alignment: .bottomTrailing) {
                            Image(systemName: "camera.circle.fill")
                                .font(.title2)
                                .foregroundStyle(.white, .blue)
                                .offset(x: 4, y: 4)
                        }
                }
                .disabled(store.isUploadingAvatar)
            } else {
                avatarView(user: user)
            }
            
            VStack(spacing: 4) {
                Text(user.displayName)
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("@\(user.username)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            HStack(spacing: 32) {
                statItem(value: store.stats.postsCount, label: "Posts", isLoading: store.isLoadingPosts)
                statItem(value: store.stats.followersCount, label: "Followers", isLoading: store.isLoadingPosts)
                statItem(value: store.stats.followingCount, label: "Following", isLoading: store.isLoadingPosts)
            }
            .padding(.top, 8)
            
            if store.isCurrentUser {
                Button {
                    // Edit profile action
                } label: {
                    Text("Edit Profile")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.bordered)
                .padding(.horizontal, 32)
            } else {
                Button {
                    store.send(.followTapped)
                } label: {
                    Text(store.isFollowing ? "Following" : "Follow")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .tint(store.isFollowing ? .gray : .blue)
                .disabled(store.isTogglingFollow)
                .padding(.horizontal, 32)
            }
        }
        .padding()
    }
    
    private func avatarView(user: User) -> some View {
        ZStack {
            AvatarView(url: user.avatarURL, size: 100)
            
            if store.isUploadingAvatar {
                Circle()
                    .fill(.black.opacity(0.5))
                    .frame(width: 100, height: 100)
                    .overlay {
                        ProgressView()
                            .tint(.white)
                    }
            }
        }
    }
    
    private func statItem(value: Int, label: String, isLoading: Bool = false) -> some View {
        VStack {
            if isLoading {
                ProgressView()
                    .scaleEffect(0.7)
                    .frame(height: 20)
            } else {
                Text(formatNumber(value))
                    .font(.headline)
            }
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(minWidth: 60)
    }
    
    private func formatNumber(_ number: Int) -> String {
        if number >= 1000 {
            return String(format: "%.1fK", Double(number) / 1000)
        }
        return "\(number)"
    }
    
    private var postsList: some View {
        Group {
            if store.isLoadingPosts {
                VStack {
                    ProgressView()
                        .padding(.top, 40)
                    Spacer()
                }
            } else if store.posts.isEmpty && !store.isLoading {
                ContentUnavailableView {
                    Label("No Posts Yet", systemImage: "photo.on.rectangle.angled")
                } description: {
                    Text(store.isCurrentUser ? "Share your first moment!" : "No posts to show")
                }
                .padding(.top, 40)
            } else {
                LazyVStack(spacing: 16) {
                    ForEach(store.posts) { post in
                        PostView(
                            post: post,
                            onLikeTapped: { post in
                                store.send(.likeTapped(post))
                            },
                            onCommentsTapped: { post in
                                store.send(.commentsTapped(post))
                            }
                        )
                        .padding(.horizontal)
                        
                        Divider()
                    }
                }
            }
        }
    }
    
    /// Compresses and resizes image data for avatar use
    private func compressImageForAvatar(data: Data) -> Data? {
        guard let uiImage = UIImage(data: data) else { return nil }
        
        // Resize to max 400x400 for avatar
        let maxSize: CGFloat = 400
        let scale = min(maxSize / uiImage.size.width, maxSize / uiImage.size.height, 1.0)
        let newSize = CGSize(width: uiImage.size.width * scale, height: uiImage.size.height * scale)
        
        let renderer = UIGraphicsImageRenderer(size: newSize)
        let resizedImage = renderer.image { _ in
            uiImage.draw(in: CGRect(origin: .zero, size: newSize))
        }
        
        // Compress to JPEG with 0.8 quality
        return resizedImage.jpegData(compressionQuality: 0.8)
    }
}

#Preview {
    ProfileView(
        store: Store(initialState: ProfileFeature.State()) {
            ProfileFeature()
        } withDependencies: {
            $0.authClient = .previewValue
            $0.profileClient = .previewValue
            $0.postClient = .previewValue
            $0.storageClient = .previewValue
            $0.followClient = .previewValue
        }
    )
}
