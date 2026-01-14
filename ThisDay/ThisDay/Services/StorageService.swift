import Foundation
import Supabase

/// Service for handling file storage operations with Supabase Storage
actor StorageService {
    static let shared = StorageService()
    
    private let bucket = postPhotosBucket
    
    private init() {}
    
    // MARK: - Upload Operations
    
    /// Uploads a photo to Supabase Storage
    /// - Parameters:
    ///   - imageData: The image data to upload
    ///   - fileName: Optional custom file name (auto-generated if nil)
    /// - Returns: The public URL of the uploaded photo
    func uploadPhoto(
        imageData: Data,
        fileName: String? = nil
    ) async throws -> URL {
        guard let userId = await AuthService.shared.currentUserId() else {
            throw StorageError.notAuthenticated
        }
        
        let name = fileName ?? "\(UUID().uuidString.lowercased()).jpg"
        let path = "private/\(userId.uuidString.lowercased())/\(name)"
        
        _ = try await supabase.storage
            .from(bucket)
            .upload(
                path: path,
                file: imageData,
                options: FileOptions(
                    contentType: "image/jpeg",
                    upsert: false
                )
            )
        
        // Get the public URL
        let publicURL = try supabase.storage
            .from(bucket)
            .getPublicURL(path: path)
        
        return publicURL
    }
    
    /// Uploads a photo and generates a thumbnail
    /// - Parameters:
    ///   - imageData: The original image data
    ///   - thumbnailData: The thumbnail image data
    ///   - fileName: Base file name (without extension)
    /// - Returns: Tuple of (original URL, thumbnail URL)
    func uploadPhotoWithThumbnail(
        imageData: Data,
        thumbnailData: Data,
        fileName: String? = nil
    ) async throws -> (url: URL, thumbnailURL: URL) {
        guard let userId = await AuthService.shared.currentUserId() else {
            throw StorageError.notAuthenticated
        }
        
        let baseName = fileName ?? UUID().uuidString.lowercased()
        let originalPath = "private/\(userId.uuidString.lowercased())/\(baseName).jpg"
        let thumbnailPath = "private/\(userId.uuidString.lowercased())/\(baseName)_thumb.jpg"
        
        // Upload both concurrently
        async let originalUpload = supabase.storage
            .from(bucket)
            .upload(
                path: originalPath,
                file: imageData,
                options: FileOptions(contentType: "image/jpeg", upsert: false)
            )
        
        async let thumbnailUpload = supabase.storage
            .from(bucket)
            .upload(
                path: thumbnailPath,
                file: thumbnailData,
                options: FileOptions(contentType: "image/jpeg", upsert: false)
            )
        
        _ = try await (originalUpload, thumbnailUpload)
        
        // Get public URLs
        let originalURL = try supabase.storage
            .from(bucket)
            .getPublicURL(path: originalPath)
        
        let thumbnailURL = try supabase.storage
            .from(bucket)
            .getPublicURL(path: thumbnailPath)
        
        return (originalURL, thumbnailURL)
    }
    
    /// Uploads multiple photos
    /// - Parameter images: Array of image data
    /// - Returns: Array of public URLs in the same order
    func uploadPhotos(images: [Data]) async throws -> [URL] {
        try await withThrowingTaskGroup(of: (Int, URL).self) { group in
            for (index, imageData) in images.enumerated() {
                group.addTask {
                    let url = try await self.uploadPhoto(imageData: imageData)
                    return (index, url)
                }
            }
            
            var results: [(Int, URL)] = []
            for try await result in group {
                results.append(result)
            }
            
            return results.sorted { $0.0 < $1.0 }.map { $0.1 }
        }
    }
    
    /// Uploads multiple photos with thumbnails
    /// - Parameter images: Array of tuples containing (original data, thumbnail data)
    /// - Returns: Array of (url, thumbnailURL) tuples in the same order
    func uploadPhotosWithThumbnails(
        images: [(imageData: Data, thumbnailData: Data)]
    ) async throws -> [(url: URL, thumbnailURL: URL)] {
        try await withThrowingTaskGroup(of: (Int, URL, URL).self) { group in
            for (index, image) in images.enumerated() {
                group.addTask {
                    let result = try await self.uploadPhotoWithThumbnail(
                        imageData: image.imageData,
                        thumbnailData: image.thumbnailData
                    )
                    return (index, result.url, result.thumbnailURL)
                }
            }
            
            var results: [(Int, URL, URL)] = []
            for try await result in group {
                results.append(result)
            }
            
            return results.sorted { $0.0 < $1.0 }.map { ($0.1, $0.2) }
        }
    }
    
    // MARK: - Avatar Operations
    
    /// Uploads an avatar image for the current user
    /// - Parameter imageData: The image data to upload
    /// - Returns: The public URL of the uploaded avatar
    func uploadAvatar(imageData: Data) async throws -> URL {
        guard let userId = await AuthService.shared.currentUserId() else {
            throw StorageError.notAuthenticated
        }
        
        // Use a consistent filename so it gets overwritten each time
        let path = "private/\(userId.uuidString.lowercased())/avatar.jpg"
        
        _ = try await supabase.storage
            .from(avatarsBucket)
            .upload(
                path: path,
                file: imageData,
                options: FileOptions(
                    contentType: "image/jpeg",
                    upsert: true // Overwrite existing avatar
                )
            )
        
        // Get the public URL with a cache-busting query parameter
        let publicURL = try supabase.storage
            .from(avatarsBucket)
            .getPublicURL(path: path)
        
        // Add timestamp to bust cache
        var components = URLComponents(url: publicURL, resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "t", value: "\(Int(Date().timeIntervalSince1970))")]
        
        return components.url ?? publicURL
    }
    
    // MARK: - Delete Operations
    
    /// Deletes a photo from storage
    /// - Parameter url: The public URL of the photo to delete
    func deletePhoto(url: URL) async throws {
        // Extract the path from the URL
        let path = extractPath(from: url)
        
        try await supabase.storage
            .from(bucket)
            .remove(paths: [path])
    }
    
    /// Deletes multiple photos from storage
    /// - Parameter urls: Array of public URLs to delete
    func deletePhotos(urls: [URL]) async throws {
        let paths = urls.map { extractPath(from: $0) }
        
        try await supabase.storage
            .from(bucket)
            .remove(paths: paths)
    }
    
    // MARK: - URL Operations
    
    /// Gets the public URL for a storage path
    /// - Parameter path: The storage path
    /// - Returns: The public URL
    func getPublicURL(path: String) throws -> URL {
        try supabase.storage
            .from(bucket)
            .getPublicURL(path: path)
    }
    
    /// Creates a signed URL for temporary access
    /// - Parameters:
    ///   - path: The storage path
    ///   - expiresIn: Seconds until expiration (default 1 hour)
    /// - Returns: The signed URL
    func getSignedURL(path: String, expiresIn: Int = 3600) async throws -> URL {
        try await supabase.storage
            .from(bucket)
            .createSignedURL(path: path, expiresIn: expiresIn)
    }
    
    // MARK: - Helpers
    
    /// Extracts the storage path from a public URL
    private func extractPath(from url: URL) -> String {
        // Public URLs have format: .../storage/v1/object/public/bucket-name/path
        // We need to extract the path after the bucket name
        let components = url.pathComponents
        if let bucketIndex = components.firstIndex(of: bucket) {
            let pathComponents = components.suffix(from: components.index(after: bucketIndex))
            return pathComponents.joined(separator: "/")
        }
        return url.lastPathComponent
    }
    
    /// Lists all files for the current user
    /// - Returns: Array of file names
    func listUserFiles() async throws -> [String] {
        guard let userId = await AuthService.shared.currentUserId() else {
            throw StorageError.notAuthenticated
        }
        
        let files = try await supabase.storage
            .from(bucket)
            .list(path: "private/\(userId.uuidString.lowercased())")
        
        return files.map { $0.name }
    }
}

// MARK: - Storage Errors

enum StorageError: LocalizedError {
    case notAuthenticated
    case uploadFailed(String)
    case deleteFailed(String)
    case fileNotFound
    case invalidFileType
    case fileTooLarge
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "User is not authenticated"
        case .uploadFailed(let message):
            return "Upload failed: \(message)"
        case .deleteFailed(let message):
            return "Delete failed: \(message)"
        case .fileNotFound:
            return "File not found"
        case .invalidFileType:
            return "Invalid file type. Only images are allowed."
        case .fileTooLarge:
            return "File is too large. Maximum size is 10MB."
        }
    }
}
