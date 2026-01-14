import ComposableArchitecture
import Foundation
import PhotosUI
import SwiftUI
import ImageIO

@Reducer
struct ComposeFeature {
    @ObservableState
    struct State: Equatable {
        var caption: String = ""
        var selectedPhotos: [SelectedPhoto] = []
        var isLoading: Bool = false
        var errorMessage: String?
        var photosPickerItems: [PhotosPickerItem] = []
        
        var canPost: Bool {
            !selectedPhotos.isEmpty && selectedPhotos.count <= 6 && !isLoading
        }
        
        var photoCountText: String {
            "\(selectedPhotos.count)/6 photos"
        }
        
        struct SelectedPhoto: Equatable, Identifiable {
            let id: UUID
            let image: UIImage
            let thumbnail: UIImage
            let takenAt: Date?
            
            static func == (lhs: SelectedPhoto, rhs: SelectedPhoto) -> Bool {
                lhs.id == rhs.id
            }
        }
    }
    
    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case photosPickerItemsChanged([PhotosPickerItem])
        case photoLoaded(Result<State.SelectedPhoto, Error>)
        case removePhoto(UUID)
        case postTapped
        case postCompleted(Result<Post, Error>)
        case delegate(Delegate)
        
        @CasePathable
        enum Delegate {
            case postCreated(Post)
            case dismissed
        }
    }
    
    @Dependency(\.storageClient) var storageClient
    @Dependency(\.postClient) var postClient
    
    var body: some ReducerOf<Self> {
        BindingReducer()
        
        Reduce { state, action in
            switch action {
            case .binding:
                return .none
                
            case .photosPickerItemsChanged(let items):
                state.photosPickerItems = items
                state.errorMessage = nil
                
                // Load images from picker items
                return .run { send in
                    for item in items {
                        do {
                            guard let data = try await item.loadTransferable(type: Data.self),
                                  let uiImage = UIImage(data: data) else {
                                continue
                            }
                            
                            // Extract EXIF date taken
                            let takenAt = extractDateTaken(from: data)
                            
                            // Create thumbnail
                            let thumbnail = uiImage.resized(toMaxDimension: 300) ?? uiImage
                            let fullSize = uiImage.resized(toMaxDimension: 1200) ?? uiImage
                            
                            let photo = State.SelectedPhoto(
                                id: UUID(),
                                image: fullSize,
                                thumbnail: thumbnail,
                                takenAt: takenAt
                            )
                            await send(.photoLoaded(.success(photo)))
                        } catch {
                            await send(.photoLoaded(.failure(error)))
                        }
                    }
                }
                
            case .photoLoaded(.success(let photo)):
                if state.selectedPhotos.count < 6 {
                    state.selectedPhotos.append(photo)
                }
                return .none
                
            case .photoLoaded(.failure(let error)):
                state.errorMessage = "Failed to load photo: \(error.localizedDescription)"
                return .none
                
            case .removePhoto(let id):
                state.selectedPhotos.removeAll { $0.id == id }
                return .none
                
            case .postTapped:
                guard state.canPost else { return .none }
                
                state.isLoading = true
                state.errorMessage = nil
                
                let photos = state.selectedPhotos
                let caption = state.caption.isEmpty ? nil : state.caption
                
                return .run { send in
                    do {
                        // Upload all photos
                        var photoURLs: [(URL, URL?, Date?)] = []
                        
                        for photo in photos {
                            guard let imageData = photo.image.jpegData(compressionQuality: 0.8),
                                  let thumbnailData = photo.thumbnail.jpegData(compressionQuality: 0.7) else {
                                continue
                            }
                            
                            let (url, thumbnailURL) = try await storageClient.uploadPhotoWithThumbnail(imageData, thumbnailData)
                            photoURLs.append((url, thumbnailURL, photo.takenAt))
                        }
                        
                        // Create post
                        let post = try await postClient.createPost(caption, photoURLs)
                        await send(.postCompleted(.success(post)))
                    } catch {
                        await send(.postCompleted(.failure(error)))
                    }
                }
                
            case .postCompleted(.success(let post)):
                state.isLoading = false
                return .send(.delegate(.postCreated(post)))
                
            case .postCompleted(.failure(let error)):
                state.isLoading = false
                state.errorMessage = error.localizedDescription
                return .none
                
            case .delegate:
                return .none
            }
        }
    }
}

// MARK: - UIImage Extension for Resizing

extension UIImage {
    func resized(toMaxDimension maxDimension: CGFloat) -> UIImage? {
        let aspectRatio = size.width / size.height
        var newSize: CGSize
        
        if size.width > size.height {
            newSize = CGSize(width: maxDimension, height: maxDimension / aspectRatio)
        } else {
            newSize = CGSize(width: maxDimension * aspectRatio, height: maxDimension)
        }
        
        // Don't upscale
        if newSize.width > size.width || newSize.height > size.height {
            return self
        }
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        defer { UIGraphicsEndImageContext() }
        
        draw(in: CGRect(origin: .zero, size: newSize))
        return UIGraphicsGetImageFromCurrentImageContext()
    }
}

// MARK: - EXIF Date Extraction

private func extractDateTaken(from data: Data) -> Date? {
    guard let source = CGImageSourceCreateWithData(data as CFData, nil),
          let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any],
          let exif = properties[kCGImagePropertyExifDictionary as String] as? [String: Any] else {
        return nil
    }
    
    // Try DateTimeOriginal first (when photo was taken)
    if let dateString = exif[kCGImagePropertyExifDateTimeOriginal as String] as? String {
        return parseExifDate(dateString)
    }
    
    // Fall back to DateTimeDigitized
    if let dateString = exif[kCGImagePropertyExifDateTimeDigitized as String] as? String {
        return parseExifDate(dateString)
    }
    
    return nil
}

private func parseExifDate(_ dateString: String) -> Date? {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
    formatter.timeZone = TimeZone.current
    return formatter.date(from: dateString)
}
