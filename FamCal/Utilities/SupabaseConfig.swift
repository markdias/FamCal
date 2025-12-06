//
//  SupabaseConfig.swift
//  FamCal
//
//  Configuration file for Supabase credentials
//

import Foundation

/// Configuration for Supabase connection
/// 
/// ⚠️ IMPORTANT: Enter your Supabase credentials below
struct SupabaseConfig {
    /// Your Supabase project URL
    /// Example: "https://xxxxx.supabase.co"
    /// 
    /// 👉 ENTER YOUR SUPABASE URL HERE:
    static let supabaseURL = "https://tzkspidmzlipujsnxpzc.supabase.co"
    
    /// Your Supabase anonymous/public API key
    /// Found in: Supabase Dashboard > Project Settings > API > anon/public key
    /// 
    /// 👉 ENTER YOUR SUPABASE ANON KEY HERE:
    static let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InR6a3NwaWRtemxpcHVqc254cHpjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjM4OTI2MTYsImV4cCI6MjA3OTQ2ODYxNn0.QMKZYMrESCOCT0KCHAKhPU995_mIB1F3l4Y4uq8s1uM"

    /// Google client ID from Google Cloud console (matches the Supabase provider config)
    /// Example: "12345-abcdef.apps.googleusercontent.com"
    static let googleClientID = "555073180680-eku35n9vu7rgvr8nohtc0l5dai0fi5av.apps.googleusercontent.com"
    /// Reversed Google client ID for the URL scheme (e.g., "com.googleusercontent.apps.12345-abcdef")
    static let googleReversedClientID = "com.googleusercontent.apps.555073180680-eku35n9vu7rgvr8nohtc0l5dai0fi5av"

    /// Optional: if your invite Edge Function requires a secret header (x-invite-fn-key), set it here.
    /// Leave blank if the function relies solely on JWT verification.
    static let inviteFunctionKey = "pimsyx-Hovma5-zocwyz"

    /// Optional: if your delete-account Edge Function requires a secret header (x-delete-account-fn-key), set it here.
    /// Leave blank if the function relies solely on JWT verification.
    static let deleteAccountFunctionKey = ""

    // MARK: - Validation
    
    /// Check if credentials are configured
    static var isConfigured: Bool {
        return !supabaseURL.isEmpty && 
               !supabaseAnonKey.isEmpty && 
               supabaseAnonKey != "YOUR_SUPABASE_ANON_KEY_HERE"
    }
    
    /// Validate configuration and provide helpful error messages
    static func validate() throws {
        guard !supabaseURL.isEmpty else {
            throw ConfigError.missingURL
        }
        
        guard !supabaseAnonKey.isEmpty else {
            throw ConfigError.missingKey
        }
        
        guard supabaseAnonKey != "YOUR_SUPABASE_ANON_KEY_HERE" else {
            throw ConfigError.keyNotSet
        }
        
        guard supabaseURL.hasPrefix("https://") else {
            throw ConfigError.invalidURL
        }
    }
    
    enum ConfigError: LocalizedError {
        case missingURL
        case missingKey
        case keyNotSet
        case invalidURL
        
        var errorDescription: String? {
            switch self {
            case .missingURL:
                return "Supabase URL is missing. Please set it in SupabaseConfig.swift"
            case .missingKey:
                return "Supabase anon key is missing. Please set it in SupabaseConfig.swift"
            case .keyNotSet:
                return "Please replace 'YOUR_SUPABASE_ANON_KEY_HERE' with your actual Supabase anon key in SupabaseConfig.swift"
            case .invalidURL:
                return "Supabase URL must start with 'https://'"
            }
        }
    }
}
