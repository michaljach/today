import Foundation
import Supabase

// MARK: - Secrets Configuration

private struct SecretsConfig: Decodable {
    let supabaseURL: String
    let supabaseAnonKey: String
    let postPhotosBucket: String
    let avatarsBucket: String
}

private let secrets: SecretsConfig = {
    guard let url = Bundle.main.url(forResource: "Secrets", withExtension: "json") else {
        fatalError("Secrets.json not found. Copy Secrets.example.json to Secrets.json and fill in your values.")
    }
    
    do {
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(SecretsConfig.self, from: data)
    } catch {
        fatalError("Failed to load Secrets.json: \(error)")
    }
}()

// MARK: - Supabase Client

/// Shared Supabase client instance for the app
let supabase = SupabaseClient(
    supabaseURL: URL(string: secrets.supabaseURL)!,
    supabaseKey: secrets.supabaseAnonKey
)

/// Storage bucket name for post photos
let postPhotosBucket = secrets.postPhotosBucket

/// Storage bucket name for user avatars
let avatarsBucket = secrets.avatarsBucket
