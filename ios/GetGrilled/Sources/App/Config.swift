import Foundation

/// Fill in after provisioning the Supabase project and Vercel deployment.
/// Never put a service-role key or LLM API key here — those live only on Vercel.
enum Config {
    static let supabaseURL = URL(string: "https://jwalhqndnzsuliomiruz.supabase.co")!
    static let supabaseAnonKey = "sb_publishable_pB4UOo9PVkmUYGsLMHBbZw_72TZLJNw"
    static let apiBaseURL = URL(string: "https://get-grilled-mu.vercel.app")!
}
