import ComposableArchitecture
import PhotosUI
import SwiftUI

struct ComposeView: View {
    @Bindable var store: StoreOf<ComposeFeature>
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Photo picker section
                    photoSection
                    
                    // Caption input
                    captionSection
                    
                    // Error message
                    if let errorMessage = store.errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("New Post")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        store.send(.delegate(.dismissed))
                    }
                    .disabled(store.isLoading)
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    if store.isLoading {
                        ProgressView()
                    } else {
                        Button("Post") {
                            store.send(.postTapped)
                        }
                        .fontWeight(.semibold)
                        .disabled(!store.canPost)
                    }
                }
            }
        }
        .interactiveDismissDisabled(store.isLoading)
    }
    
    private var photoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Photos")
                    .font(.headline)
                Spacer()
                Text(store.photoCountText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    // Add photo button
                    if store.selectedPhotos.count < 6 {
                        PhotosPicker(
                            selection: Binding(
                                get: { store.photosPickerItems },
                                set: { store.send(.photosPickerItemsChanged($0)) }
                            ),
                            maxSelectionCount: 6 - store.selectedPhotos.count,
                            matching: .images
                        ) {
                            VStack(spacing: 8) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 30))
                                Text("Add")
                                    .font(.caption)
                            }
                            .foregroundStyle(.accentColor)
                            .frame(width: 100, height: 100)
                            .background(Color.accentColor.opacity(0.1))
                            .cornerRadius(12)
                        }
                        .disabled(store.isLoading)
                    }
                    
                    // Selected photos
                    ForEach(store.selectedPhotos) { photo in
                        selectedPhotoView(photo)
                    }
                }
                .padding(.horizontal)
            }
        }
    }
    
    private func selectedPhotoView(_ photo: ComposeFeature.State.SelectedPhoto) -> some View {
        Image(uiImage: photo.thumbnail)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: 100, height: 100)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(alignment: .topTrailing) {
                Button {
                    store.send(.removePhoto(photo.id))
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.white)
                        .background(Circle().fill(.black.opacity(0.5)))
                }
                .padding(4)
                .disabled(store.isLoading)
            }
    }
    
    private var captionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Caption")
                .font(.headline)
            
            TextField("Write a caption...", text: $store.caption, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(5...10)
                .disabled(store.isLoading)
        }
        .padding(.horizontal)
    }
}

#Preview {
    ComposeView(
        store: Store(initialState: ComposeFeature.State()) {
            ComposeFeature()
        } withDependencies: {
            $0.storageClient = .previewValue
            $0.postClient = .previewValue
        }
    )
}
