import Foundation

struct Photo: Equatable, Identifiable, Codable {
    let id: UUID
    let postId: UUID?
    let url: URL
    let thumbnailURL: URL?
    let sortOrder: Int
    let createdAt: Date?
    let takenAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case postId = "post_id"
        case url
        case thumbnailURL = "thumbnail_url"
        case sortOrder = "sort_order"
        case createdAt = "created_at"
        case takenAt = "taken_at"
    }
    
    init(
        id: UUID = UUID(),
        postId: UUID? = nil,
        url: URL,
        thumbnailURL: URL? = nil,
        sortOrder: Int = 0,
        createdAt: Date? = nil,
        takenAt: Date? = nil
    ) {
        self.id = id
        self.postId = postId
        self.url = url
        self.thumbnailURL = thumbnailURL
        self.sortOrder = sortOrder
        self.createdAt = createdAt
        self.takenAt = takenAt
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        postId = try container.decodeIfPresent(UUID.self, forKey: .postId)
        
        // Handle URL decoding from string
        let urlString = try container.decode(String.self, forKey: .url)
        guard let parsedURL = URL(string: urlString) else {
            throw DecodingError.dataCorruptedError(forKey: .url, in: container, debugDescription: "Invalid URL string")
        }
        url = parsedURL
        
        if let thumbnailString = try container.decodeIfPresent(String.self, forKey: .thumbnailURL) {
            thumbnailURL = URL(string: thumbnailString)
        } else {
            thumbnailURL = nil
        }
        
        sortOrder = try container.decodeIfPresent(Int.self, forKey: .sortOrder) ?? 0
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
        takenAt = try container.decodeIfPresent(Date.self, forKey: .takenAt)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(postId, forKey: .postId)
        try container.encode(url.absoluteString, forKey: .url)
        try container.encodeIfPresent(thumbnailURL?.absoluteString, forKey: .thumbnailURL)
        try container.encode(sortOrder, forKey: .sortOrder)
        try container.encodeIfPresent(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(takenAt, forKey: .takenAt)
    }
}

// MARK: - DTO for creating photos (without id, timestamps)
struct CreatePhotoDTO: Codable {
    let postId: UUID
    let url: String
    let thumbnailURL: String?
    let sortOrder: Int
    let takenAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case postId = "post_id"
        case url
        case thumbnailURL = "thumbnail_url"
        case sortOrder = "sort_order"
        case takenAt = "taken_at"
    }
}

// MARK: - Mock Data
extension Photo {
    static func mock(index: Int, postId: UUID? = nil) -> Photo {
        Photo(
            postId: postId,
            url: URL(string: "https://picsum.photos/seed/\(index)/600/600")!,
            thumbnailURL: URL(string: "https://picsum.photos/seed/\(index)/200/200"),
            sortOrder: index
        )
    }
}
