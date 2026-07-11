import Foundation
import Supabase

@MainActor
final class SupabaseManager {
    static let shared = SupabaseManager()
    
    // TODO: Replace with real URL and Anon Key from your Supabase project dashboard
    let client = SupabaseClient(
        supabaseURL: URL(string: "https://qhgtsguaahpswuoykoxx.supabase.co")!,
        supabaseKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFoZ3RzZ3VhYWhwc3d1b3lrb3h4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODM3NzkxNDIsImV4cCI6MjA5OTM1NTE0Mn0.00Gxl_u9QCCmOWLRhSZY4Yrg6ZeQK2Q7T3NBh0uKJis"
    )
    
    private init() {}
}
