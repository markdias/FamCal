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
    var accessToken: String?

    // UserDefaults keys for session persistence
    private let userDefaultsKeyUserId = "com.famcal.auth.userId"
    private let userDefaultsKeyEmail = "com.famcal.auth.userEmail"
    private let userDefaultsKeyAccessToken = "com.famcal.auth.accessToken"
    private let userDefaultsKeyIsAuthenticated = "com.famcal.auth.isAuthenticated"

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
        print("ℹ️ Checking for existing session...")

        let defaults = UserDefaults.standard

        // Try to restore session from UserDefaults
        if let savedUserId = defaults.string(forKey: userDefaultsKeyUserId),
           let savedEmail = defaults.string(forKey: userDefaultsKeyEmail),
           let savedAccessToken = defaults.string(forKey: userDefaultsKeyAccessToken),
           defaults.bool(forKey: userDefaultsKeyIsAuthenticated) {

            print("✅ Found existing session for: \(savedEmail)")

            // Restore the session
            await MainActor.run {
                self.userId = savedUserId
                self.userEmail = savedEmail
                self.accessToken = savedAccessToken
                self.isAuthenticated = true

                print("✅ Session restored successfully")
            }
        } else {
            print("ℹ️ No existing session found - user will need to log in")
        }
    }

    /// Save session to persistent storage
    func saveSession() {
        let defaults = UserDefaults.standard

        if isAuthenticated, let userId = userId, let email = userEmail, let token = accessToken {
            defaults.set(userId, forKey: userDefaultsKeyUserId)
            defaults.set(email, forKey: userDefaultsKeyEmail)
            defaults.set(token, forKey: userDefaultsKeyAccessToken)
            defaults.set(true, forKey: userDefaultsKeyIsAuthenticated)
            print("ℹ️ Session saved to persistent storage")
        }
    }

    /// Clear session from persistent storage
    private func clearSession() {
        let defaults = UserDefaults.standard

        defaults.removeObject(forKey: userDefaultsKeyUserId)
        defaults.removeObject(forKey: userDefaultsKeyEmail)
        defaults.removeObject(forKey: userDefaultsKeyAccessToken)
        defaults.removeObject(forKey: userDefaultsKeyIsAuthenticated)
        print("ℹ️ Session cleared from persistent storage")
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
                // Log raw response for debugging
                if let rawResponse = String(data: data, encoding: .utf8) {
                    print("ℹ️ Signup raw response: \(rawResponse)")
                }

                do {
                    let response = try JSONDecoder().decode(AuthResponse.self, from: data)
                    self.userId = response.user.id
                    self.userEmail = response.user.email
                    if let accessToken = response.session?.access_token {
                        self.accessToken = accessToken
                    }
                    self.isAuthenticated = true
                    self.saveSession()  // Persist session
                    print("✅ User signed up successfully: \(email)")
                    print("ℹ️ User ID (from parsing): \(response.user.id)")
                } catch {
                    // If response is empty or different format, still consider signup successful if status is 200/201
                    print("⚠️ Signup successful but could not parse AuthResponse: \(error)")
                    print("ℹ️ Attempting manual userId extraction from response...")

                    // Manually parse the JSON response
                    guard let jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                        print("❌ Could not parse signup response as JSON")
                        self.userEmail = email
                        self.isAuthenticated = true
                        print("✅ User signed up successfully: \(email)")
                        return
                    }

                    print("ℹ️ Signup response JSON keys: \(jsonObject.keys)")

                    // Try to find userId in various places
                    var foundUserId: String? = nil

                    if let userId = jsonObject["id"] as? String {
                        foundUserId = userId
                        print("ℹ️ Found id at root level: \(userId)")
                    } else if let userDict = jsonObject["user"] as? [String: Any],
                              let userId = userDict["id"] as? String {
                        foundUserId = userId
                        print("ℹ️ Found userId in user object: \(userId)")
                    }

                    if let userId = foundUserId {
                        self.userId = userId
                        print("✅ Successfully extracted User ID from signup: \(userId)")
                    } else {
                        // Generate from email as last resort
                        let generatedId = email.lowercased().replacingOccurrences(of: "@", with: "-").replacingOccurrences(of: ".", with: "-")
                        self.userId = generatedId
                        print("⚠️ Using generated User ID: \(generatedId)")
                    }

                    // Try to get access token
                    if let accessToken = jsonObject["access_token"] as? String {
                        self.accessToken = accessToken
                        print("ℹ️ Found access_token in signup response")
                    }

                    self.userEmail = email
                    self.isAuthenticated = true
                    self.saveSession()  // Persist session
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
            // Use auth/v1/token with grant_type as query parameter
            // Supabase GoTrue requires:
            // - grant_type=password as query parameter
            // - JSON content-type body with email and password
            var urlComponents = URLComponents(url: supabaseURL.appendingPathComponent("auth/v1/token"), resolvingAgainstBaseURL: false)!
            urlComponents.queryItems = [URLQueryItem(name: "grant_type", value: "password")]
            let url = urlComponents.url!

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue(anonKey, forHTTPHeaderField: "apikey")

            struct SignInBody: Encodable {
                let email: String
                let password: String
            }

            let body = SignInBody(email: email, password: password)
            request.httpBody = try JSONEncoder().encode(body)

            print("ℹ️ Sign-in request: POST \(url.absoluteString)")
            print("ℹ️ Content-Type: application/json")
            print("ℹ️ apikey: \(anonKey.prefix(20))...")
            print("ℹ️ Body: {\"email\":\"\(email)\",\"password\":\"***\"}")
            if let bodyStr = String(data: request.httpBody ?? Data(), encoding: .utf8) {
                print("ℹ️ Raw body (masked): \(bodyStr.replacingOccurrences(of: password, with: String(repeating: "*", count: password.count)))")
            }

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw NSError(domain: "InvalidResponse", code: -1)
            }

            print("ℹ️ Response status: \(httpResponse.statusCode)")

            // Always log the raw response for debugging
            if let rawResponse = String(data: data, encoding: .utf8) {
                print("ℹ️ Raw response: \(rawResponse)")
            }

            if httpResponse.statusCode == 200 {
                do {
                    let response = try JSONDecoder().decode(TokenResponse.self, from: data)
                    self.userId = response.user.id
                    self.userEmail = response.user.email
                    self.accessToken = response.access_token
                    self.isAuthenticated = true
                    self.saveSession()  // Persist session
                    print("✅ User signed in successfully: \(email)")
                    print("ℹ️ User ID (from parsing): \(response.user.id)")
                } catch let decodingError {
                    // Fallback: try to extract userId from raw JSON
                    print("⚠️ Could not parse TokenResponse: \(decodingError)")
                    print("ℹ️ Attempting manual JSON extraction...")

                    // Manually parse the JSON response
                    guard let jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                        print("❌ Could not parse response as JSON at all")
                        throw NSError(domain: "NoUserID", code: -1)
                    }

                    print("ℹ️ Response JSON keys: \(jsonObject.keys)")

                    // Try to find userId in various places
                    var foundUserId: String? = nil

                    if let userId = jsonObject["user_id"] as? String {
                        foundUserId = userId
                        print("ℹ️ Found userId at root level: \(userId)")
                    } else if let userId = jsonObject["id"] as? String {
                        foundUserId = userId
                        print("ℹ️ Found id at root level: \(userId)")
                    } else if let userDict = jsonObject["user"] as? [String: Any] {
                        print("ℹ️ Found 'user' object with keys: \(userDict.keys)")
                        if let userId = userDict["id"] as? String {
                            foundUserId = userId
                            print("ℹ️ Found userId in user object: \(userId)")
                        }
                    }

                    // If we found a userId, use it
                    if let userId = foundUserId {
                        self.userId = userId
                        print("✅ Successfully extracted User ID: \(userId)")
                    } else {
                        // Last resort: generate from email
                        let generatedId = email.lowercased().replacingOccurrences(of: "@", with: "-").replacingOccurrences(of: ".", with: "-")
                        self.userId = generatedId
                        print("⚠️ Could not find userId in response, using generated ID: \(generatedId)")
                        print("⚠️ WARNING: This may cause issues. Please check Supabase response format.")
                    }

                    // Try to get access token from response
                    if let accessToken = jsonObject["access_token"] as? String {
                        self.accessToken = accessToken
                        print("ℹ️ Found access_token")
                    }

                    self.userEmail = email
                    self.isAuthenticated = true
                    self.saveSession()  // Persist session
                    print("✅ User signed in successfully: \(email)")
                }
            } else {
                let errorData = String(data: data, encoding: .utf8) ?? "No error details"
                print("❌ HTTP Status: \(httpResponse.statusCode)")
                print("❌ Full error response: \(errorData)")

                // Try to parse the error response
                let decodedError = try? JSONDecoder().decode(ErrorResponse.self, from: data)

                // Build comprehensive error message from all available fields
                var errorParts: [String] = []
                if let err = decodedError?.error { errorParts.append("error: \(err)") }
                if let desc = decodedError?.error_description { errorParts.append("description: \(desc)") }
                if let msg = decodedError?.message { errorParts.append("message: \(msg)") }
                if let hint = decodedError?.hint { errorParts.append("hint: \(hint)") }
                if let details = decodedError?.details { errorParts.append("details: \(details)") }

                let errorMessage = errorParts.isEmpty ? errorData : errorParts.joined(separator: " | ")
                print("❌ Parsed error: \(errorMessage)")

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
        self.clearSession()  // Clear persisted session

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
    let hint: String?
    let details: String?
}
