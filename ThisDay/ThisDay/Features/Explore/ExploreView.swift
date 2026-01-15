import ComposableArchitecture
import SwiftUI

struct ExploreView: View {
    @Bindable var store: StoreOf<ExploreFeature>
    @State private var selectedPost: Post?
    @State private var selectedPhotoIndex: Int = 0
    @Environment(\.dismiss) private var dismiss
    
    private let columns = [
        GridItem(.flexible(), spacing: 4),
        GridItem(.flexible(), spacing: 4),
        GridItem(.flexible(), spacing: 4)
    ]
    
    var body: some View {
        NavigationStack {
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
                } else {
                    mainContent
                }
            }
            .navigationTitle("Explore")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(
                text: $store.searchQuery,
                prompt: "Search users"
            )
            .onSubmit(of: .search) {
                store.send(.searchUsers)
            }
            .navigationDestination(item: $store.scope(state: \.destination?.profile, action: \.destination.profile)) { profileStore in
                ProfileView(store: profileStore)
            }
        }
        .onAppear {
            store.send(.onAppear)
        }
        .sheet(isPresented: Binding(
            get: { selectedPost != nil },
            set: { if !$0 { selectedPost = nil } }
        )) {
            if let post = selectedPost {
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
    
    private var mainContent: some View {
        GeometryReader { geometry in
            let cellSize = (geometry.size.width - 8) / 3 // 3 columns with 4pt spacing
            
            ScrollView {
                VStack(spacing: 0) {
                    // Search Results
                    if !store.searchResults.isEmpty {
                        searchResultsSection
                    } else if store.searchQuery.isEmpty {
                        // Suggested Users Section (only when not searching)
                        if !store.suggestedUsers.isEmpty {
                            suggestedUsersSection
                        }
                        
                        // Photo Grid
                        photoGrid(cellSize: cellSize)
                    } else if store.isSearching {
                        ProgressView("Searching...")
                            .frame(maxWidth: .infinity)
                            .padding(.top, 40)
                    } else {
                        // No results found
                        ContentUnavailableView {
                            Label("No Users Found", systemImage: "person.slash")
                        } description: {
                            Text("No users match \"\(store.searchQuery)\"")
                        }
                        .padding(.top, 40)
                    }
                }
            }
            .refreshable {
                await store.send(.refresh).finish()
            }
        }
    }
    
    private var suggestedUsersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Suggested Users")
                .font(.headline)
                .padding(.horizontal)
                .padding(.top, 12)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(store.suggestedUsers, id: \.id) { user in
                        Button {
                            store.send(.userTapped(user))
                        } label: {
                            VStack(spacing: 8) {
                                AvatarView(url: user.avatarURL, size: 64)
                                
                                VStack(spacing: 2) {
                                    Text(user.displayName)
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .lineLimit(1)
                                    Text("@\(user.username)")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                            }
                            .frame(width: 80)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
            
            Divider()
                .padding(.top, 8)
        }
    }
    
    private var searchResultsSection: some View {
        LazyVStack(spacing: 0) {
            ForEach(store.searchResults, id: \.id) { user in
                Button {
                    store.send(.userTapped(user))
                } label: {
                    HStack(spacing: 12) {
                        AvatarView(url: user.avatarURL, size: 50)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(user.displayName)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            Text("@\(user.username)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                
                Divider()
            }
        }
        .background(Color(.systemBackground))
    }
    
    private func photoGrid(cellSize: CGFloat) -> some View {
        LazyVGrid(columns: columns, spacing: 4) {
            ForEach(store.posts) { post in
                if let firstPhoto = post.photos.first {
                    GridCell(
                        url: firstPhoto.thumbnailURL ?? firstPhoto.url,
                        hasMultiplePhotos: post.photos.count > 1,
                        avatarURL: post.user?.avatarURL,
                        size: cellSize
                    )
                    .onTapGesture {
                        selectedPhotoIndex = 0
                        selectedPost = post
                    }
                }
            }
        }
    }
}

private struct GridCell: View {
    let url: URL
    let hasMultiplePhotos: Bool
    let avatarURL: URL?
    let size: CGFloat
    
    var body: some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .empty:
                Color.gray.opacity(0.2)
                    .overlay { ProgressView() }
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            case .failure:
                Color.gray.opacity(0.2)
                    .overlay {
                        Image(systemName: "photo")
                            .foregroundStyle(.gray)
                    }
            @unknown default:
                Color.gray.opacity(0.2)
            }
        }
        .frame(width: size, height: size)
        .clipped()
        .overlay(alignment: .topTrailing) {
            if hasMultiplePhotos {
                Image(systemName: "square.fill.on.square.fill")
                    .font(.caption)
                    .foregroundStyle(.white)
                    .shadow(radius: 2)
                    .padding(6)
            }
        }
        .overlay(alignment: .bottomLeading) {
            AvatarView(url: avatarURL, size: 24)
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: 1.5)
                )
                .shadow(radius: 2)
                .padding(6)
        }
    }
}

#Preview {
    ExploreView(
        store: Store(initialState: ExploreFeature.State()) {
            ExploreFeature()
        } withDependencies: {
            $0.postClient = .previewValue
            $0.profileClient = .previewValue
        }
    )
}
