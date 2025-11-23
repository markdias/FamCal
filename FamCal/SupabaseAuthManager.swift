//
//  SupabaseAuthManager.swift
//  FamCal
//
//  Manages user authentication with Supabase using REST API
//

import Foundation
import Combine

/// Manages authentication state and operations
@MainActor
class SupabaseAuthManager: ObservableObject {
    static let shared = SupabaseAuthManager()

    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var userEmail: String?
    @Published var userId: String?

    private var cancellables = Set<AnyCancellable>()
    private let supabaseURL: URL
    private let anonKey: String

    // Access token for authenticated API calls
    private(set) var accessToken: String?

    init() {
        // Validate configuration
        do {
            try SupabaseConfig.validate()
        } catch {
            print("❌ Supabase configuration error: \(error.localizedDescription)")
            fatalError("Please configure your Supabase credentials in SupabaseConfig.swift")
        }

        self.supabaseURL = URL(string: SupabaseConfig.supabaseURL)!
        self.anonKey = SupabaseConfig.supabaseAnonKey

        print("✅ Supabase configured: \(SupabaseConfig.supabaseURL)")

        // Check for existing session
        Task {
            await checkSession()
        }
    }

    // MARK: - Session Management

    private func checkSession() async {
        print("ℹ️ Session check initialized")
    }

    // MARK: - Authentication Methods

    /// Sign up a new user with email and password
    func signUp(email: String, password: String) async throws {
        isLoading = true
        errorMessage = nil

        defer { isLoading = false }

        do {
            let url = supabaseURL.appendingPathComponent("auth/v1/signup")
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue(anonKey, forHTTPHeaderField: "apikey")

            let body: [String: String] = ["email": email, "password": password]
            request.httpBody = try JSONEncoder().encode(body)

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw NSError(domain: "InvalidResponse", code: -1)
            }

            // Accept both 200 and 201 status codes for signup
            if httpResponse.statusCode == 200 || httpResponse.statusCode == 201 {
                do {
                    let response = try JSONDecoder().decode(AuthResponse.self, from: data)
                    self.userId = response.user.id
                    self.userEmail = response.user.email
                    if let accessToken = response.session?.access_token {
                        self.accessToken = accessToken
                    }
                    self.isAuthenticated = true
                    print("✅ User signed up successfully: \(email)")
                } catch {
                    // If response is empty or different format, still consider signup successful if status is 200/201
                    print("⚠️ Signup successful but could not parse full response: \(error)")
                    self.userEmail = email
                    self.isAuthenticated = true
                    print("✅ User signed up successfully: \(email)")
                }
            } else {
                let errorData = String(data: data, encoding: .utf8) ?? "No error details"
                print("❌ HTTP Status: \(httpResponse.statusCode)")
                print("❌ Error response body: \(errorData)")

                // Try to parse the error response
                let error = try? JSONDecoder().decode(ErrorResponse.self, from: data)
                let errorMessage = error?.message ?? error?.error_description ?? error?.error ?? errorData
                print("❌ Parsed error message: \(errorMessage)")

                throw NSError(domain: "AuthError", code: httpResponse.statusCode, userInfo: ["message": errorMessage])
            }
        } catch {
            let message = "Failed to sign up: \(error.localizedDescription)"
            errorMessage = message
            print("❌ \(message)")
            throw error
        }
    }

    /// Sign in an existing user with email and password
    func signIn(email: String, password: String) async throws {
        isLoading = true
        errorMessage = nil

        defer { isLoading = false }

        do {
            let url = supabaseURL.appendingPathComponent("auth/v1/token")
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue(anonKey, forHTTPHeaderField: "apikey")

            let body: [String: String] = [
                "email": email,
                "password": password,
                "grant_type": "password"
            ]
            request.httpBody = try JSONEncoder().encode(body)

            print("ℹ️ Sign-in request: POST \(url.absoluteString)")
            print("ℹ️ Headers: Content-Type=application/json, apikey=\(anonKey.prefix(20))...")
            print("ℹ️ Body: email=\(email), grant_type=password")

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw NSError(domain: "InvalidResponse", code: -1)
            }

            if httpResponse.statusCode == 200 {
                do {
                    let response = try JSONDecoder().decode(TokenResponse.self, from: data)
                    self.userId = response.user.id
                    self.userEmail = response.user.email
                    self.accessToken = response.access_token
                    self.isAuthenticated = true
                    print("✅ User signed in successfully: \(email)")
                } catch {
                    // Fallback: if response format is different, still mark as authenticated with email
                    print("⚠️ Sign in successful but could not parse full response: \(error)")
                    self.userEmail = email
                    self.isAuthenticated = true
                    print("✅ User signed in successfully: \(email)")
                }
            } else {
                let errorData = String(data: data, encoding: .utf8) ?? "No error details"
                print("❌ HTTP Status: \(httpResponse.statusCode)")
                print("❌ Error response body: \(errorData)")

                // Try to parse the error response
                let error = try? JSONDecoder().decode(ErrorResponse.self, from: data)
                let errorMessage = error?.message ?? error?.error_description ?? error?.error ?? errorData
                print("❌ Parsed error message: \(errorMessage)")

                throw NSError(domain: "AuthError", code: httpResponse.statusCode, userInfo: ["message": errorMessage])
            }
        } catch {
            let message = "Failed to sign in: \(error.localizedDescription)"
            errorMessage = message
            print("❌ \(message)")
            throw error
        }
    }

    /// Sign out the current user
    func signOut() async throws {
        isLoading = true
        errorMessage = nil

        defer { isLoading = false }

        self.userId = nil
        self.userEmail = nil
        self.accessToken = nil
        self.isAuthenticated = false

        print("✅ User signed out successfully")
    }

    /// Send password reset email
    func resetPassword(email: String) async throws {
        isLoading = true
        errorMessage = nil

        defer { isLoading = false }

        do {
            let url = supabaseURL.appendingPathComponent("auth/v1/recover")
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue(anonKey, forHTTPHeaderField: "apikey")

            let body: [String: String] = ["email": email]
            request.httpBody = try JSONEncoder().encode(body)

            let (_, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw NSError(domain: "InvalidResponse", code: -1)
            }

            if httpResponse.statusCode == 200 {
                print("✅ Password reset email sent to: \(email)")
            } else {
                throw NSError(domain: "AuthError", code: httpResponse.statusCode)
            }
        } catch {
            let message = "Failed to send reset email: \(error.localizedDescription)"
            errorMessage = message
            print("❌ \(message)")
            throw error
        }
    }
}

// MARK: - Response Models

private struct AuthResponse: Codable {
    let user: User
    let session: Session?

    struct User: Codable {
        let id: String
        let email: String?
    }

    struct Session: Codable {
        let access_token: String
        let token_type: String
    }
}

private struct TokenResponse: Codable {
    let access_token: String
    let token_type: String
    let expires_in: Int
    let refresh_token: String
    let user: User

    struct User: Codable {
        let id: String
        let email: String?
    }
}

private struct ErrorResponse: Codable {
    let error: String?
    let error_description: String?
    let message: String?
}
