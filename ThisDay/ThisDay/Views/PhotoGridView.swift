import SwiftUI

struct PhotoGridView: View {
    let photos: [Photo]
    var onPhotoTapped: ((Int) -> Void)?
    
    private let gridHeight: CGFloat = 200
    private let spacing: CGFloat = 2
    
    var body: some View {
        Group {
            switch photos.count {
            case 1:
                singlePhoto
            case 2:
                twoPhotos
            case 3:
                threePhotos
            case 4:
                fourPhotos
            case 5:
                fivePhotos
            case 6:
                sixPhotos
            default:
                EmptyView()
            }
        }
        .frame(height: gridHeight)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Layout Variants
    
    // 1 photo: single image
    private var singlePhoto: some View {
        TappablePhotoThumbnail(photo: photos[0], index: 0, onTap: onPhotoTapped)
    }
    
    // 2 photos: side by side
    private var twoPhotos: some View {
        HStack(spacing: spacing) {
            TappablePhotoThumbnail(photo: photos[0], index: 0, onTap: onPhotoTapped)
            TappablePhotoThumbnail(photo: photos[1], index: 1, onTap: onPhotoTapped)
        }
    }
    
    // 3 photos: left column (1 large), right column (2 stacked)
    private var threePhotos: some View {
        HStack(spacing: spacing) {
            TappablePhotoThumbnail(photo: photos[0], index: 0, onTap: onPhotoTapped)
            
            VStack(spacing: spacing) {
                TappablePhotoThumbnail(photo: photos[1], index: 1, onTap: onPhotoTapped)
                TappablePhotoThumbnail(photo: photos[2], index: 2, onTap: onPhotoTapped)
            }
        }
    }
    
    // 4 photos: 2x2 grid
    private var fourPhotos: some View {
        VStack(spacing: spacing) {
            HStack(spacing: spacing) {
                TappablePhotoThumbnail(photo: photos[0], index: 0, onTap: onPhotoTapped)
                TappablePhotoThumbnail(photo: photos[1], index: 1, onTap: onPhotoTapped)
            }
            HStack(spacing: spacing) {
                TappablePhotoThumbnail(photo: photos[2], index: 2, onTap: onPhotoTapped)
                TappablePhotoThumbnail(photo: photos[3], index: 3, onTap: onPhotoTapped)
            }
        }
    }
    
    // 5 photos: left column (1 large), right column (2 stacked), bottom row (2)
    private var fivePhotos: some View {
        VStack(spacing: spacing) {
            HStack(spacing: spacing) {
                TappablePhotoThumbnail(photo: photos[0], index: 0, onTap: onPhotoTapped)
                
                VStack(spacing: spacing) {
                    TappablePhotoThumbnail(photo: photos[1], index: 1, onTap: onPhotoTapped)
                    TappablePhotoThumbnail(photo: photos[2], index: 2, onTap: onPhotoTapped)
                }
            }
            HStack(spacing: spacing) {
                TappablePhotoThumbnail(photo: photos[3], index: 3, onTap: onPhotoTapped)
                TappablePhotoThumbnail(photo: photos[4], index: 4, onTap: onPhotoTapped)
            }
        }
    }
    
    // 6 photos: 3x2 grid
    private var sixPhotos: some View {
        VStack(spacing: spacing) {
            HStack(spacing: spacing) {
                TappablePhotoThumbnail(photo: photos[0], index: 0, onTap: onPhotoTapped)
                TappablePhotoThumbnail(photo: photos[1], index: 1, onTap: onPhotoTapped)
                TappablePhotoThumbnail(photo: photos[2], index: 2, onTap: onPhotoTapped)
            }
            HStack(spacing: spacing) {
                TappablePhotoThumbnail(photo: photos[3], index: 3, onTap: onPhotoTapped)
                TappablePhotoThumbnail(photo: photos[4], index: 4, onTap: onPhotoTapped)
                TappablePhotoThumbnail(photo: photos[5], index: 5, onTap: onPhotoTapped)
            }
        }
    }
}

struct TappablePhotoThumbnail: View {
    let photo: Photo
    let index: Int
    var onTap: ((Int) -> Void)?
    
    var body: some View {
        PhotoThumbnail(photo: photo)
            .contentShape(Rectangle())
            .onTapGesture {
                onTap?(index)
            }
    }
}

struct PhotoThumbnail: View {
    let photo: Photo
    
    private var timeText: String? {
        guard let takenAt = photo.takenAt else { return nil }
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: takenAt)
    }
    
    var body: some View {
        Color.gray.opacity(0.2)
            .overlay {
                AsyncImage(url: photo.thumbnailURL ?? photo.url) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure:
                        Image(systemName: "photo")
                            .foregroundStyle(.gray)
                    @unknown default:
                        EmptyView()
                    }
                }
            }
            .clipped()
            .overlay(alignment: .bottomTrailing) {
                if let time = timeText {
                    Text(time)
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(.black.opacity(0.4))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        .padding(6)
                }
            }
    }
}

#Preview("Single Photo") {
    PhotoGridView(photos: [.mock(index: 1)])
        .padding()
}

#Preview("Two Photos") {
    PhotoGridView(photos: [.mock(index: 1), .mock(index: 2)])
        .padding()
}

#Preview("Three Photos") {
    PhotoGridView(photos: [.mock(index: 1), .mock(index: 2), .mock(index: 3)])
        .padding()
}

#Preview("Four Photos") {
    PhotoGridView(photos: [.mock(index: 1), .mock(index: 2), .mock(index: 3), .mock(index: 4)])
        .padding()
}

#Preview("Five Photos") {
    PhotoGridView(photos: (1...5).map { Photo.mock(index: $0) })
        .padding()
}

#Preview("Six Photos") {
    PhotoGridView(photos: (1...6).map { Photo.mock(index: $0) })
        .padding()
}
