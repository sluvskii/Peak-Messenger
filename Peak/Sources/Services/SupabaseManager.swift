import Foundation
import Supabase

@MainActor
final class SupabaseManager {
    static let shared = SupabaseManager()
    
    // TODO: Replace with real URL and Anon Key from your Supabase project dashboard
    let client = SupabaseClient(
        supabaseURL: URL(string: "https://<YOUR_PROJECT_ID>.supabase.co")!,
        supabaseKey: "<YOUR_ANON_KEY>"
    )
    
    private init() {}
}
