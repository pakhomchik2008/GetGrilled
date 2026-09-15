import Foundation

/// Fill in after provisioning the Supabase project and Vercel deployment.
/// Never put a service-role key or LLM API key here — those live only on Vercel.
enum Config {
    static let supabaseURL = URL(string: "https://YOUR-PROJECT.supabase.co")!
    static let supabaseAnonKey = "YOUR-SUPABASE-ANON-KEY"
    static let apiBaseURL = URL(string: "https://YOUR-APP.vercel.app")!
}
