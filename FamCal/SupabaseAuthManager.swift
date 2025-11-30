//
//  SupabaseAuthManager.swift
//  FamCal
//
//  Manages user authentication with Supabase using REST API
//

import Foundation
import Combine
import GoogleSignIn
import UIKit

/// Manages authentication state and operations
@MainActor
class SupabaseAuthManager: ObservableObject {
    static let shared = SupabaseAuthManager()

    @Published var isAuthenticated = false
    @Published var isGuest = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var userEmail: String?
    @Published var userId: String?

    private var cancellables = Set<AnyCancellable>()
    private let supabaseURL: URL
    private let anonKey: String

    // Access token for authenticated API calls
    var accessToken: String?
    private var refreshToken: String?

    // UserDefaults keys for session persistence
    private let userDefaultsKeyUserId = "com.famcal.auth.userId"
    private let userDefaultsKeyEmail = "com.famcal.auth.userEmail"
    private let userDefaultsKeyAccessToken = "com.famcal.auth.accessToken"
    private let userDefaultsKeyRefreshToken = "com.famcal.auth.refreshToken"
    private let userDefaultsKeyIsAuthenticated = "com.famcal.auth.isAuthenticated"
    private let userDefaultsKeyIsGuest = "com.famcal.auth.isGuest"

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

        // Check for guest mode first
        if defaults.bool(forKey: userDefaultsKeyIsGuest) {
            print("✅ Guest mode detected")
            await MainActor.run {
                self.isGuest = true
                self.isAuthenticated = false
            }
            return
        }

        // Try to restore session from UserDefaults
        if let savedUserId = defaults.string(forKey: userDefaultsKeyUserId),
           let savedEmail = defaults.string(forKey: userDefaultsKeyEmail),
           let savedAccessToken = defaults.string(forKey: userDefaultsKeyAccessToken),
           defaults.bool(forKey: userDefaultsKeyIsAuthenticated) {

            print("✅ Found existing session for: \(savedEmail)")

            let savedRefreshToken = defaults.string(forKey: userDefaultsKeyRefreshToken)

            // Restore the session
            await MainActor.run {
                self.userId = savedUserId
                self.userEmail = savedEmail
                self.accessToken = savedAccessToken
                self.refreshToken = savedRefreshToken
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
            if let refreshToken = refreshToken {
                defaults.set(refreshToken, forKey: userDefaultsKeyRefreshToken)
            }
            defaults.set(true, forKey: userDefaultsKeyIsAuthenticated)
            // Ensure guest flag is cleared when saving a real session
            defaults.set(false, forKey: userDefaultsKeyIsGuest)

            // Also save to app group for widget access
            if let appGroupDefaults = UserDefaults(suiteName: "group.com.markdias.famli") {
                appGroupDefaults.set(true, forKey: userDefaultsKeyIsAuthenticated)
                appGroupDefaults.synchronize()
            }

            print("ℹ️ Session saved to persistent storage")
        }
    }

    /// Clear session from persistent storage
    private func clearSession() {
        let defaults = UserDefaults.standard

        defaults.removeObject(forKey: userDefaultsKeyUserId)
        defaults.removeObject(forKey: userDefaultsKeyEmail)
        defaults.removeObject(forKey: userDefaultsKeyAccessToken)
        defaults.removeObject(forKey: userDefaultsKeyRefreshToken)
        defaults.removeObject(forKey: userDefaultsKeyIsAuthenticated)
        defaults.removeObject(forKey: userDefaultsKeyIsGuest)

        // Also clear from app group for widget access
        if let appGroupDefaults = UserDefaults(suiteName: "group.com.markdias.famli") {
            appGroupDefaults.removeObject(forKey: userDefaultsKeyIsAuthenticated)
            appGroupDefaults.synchronize()
        }

        print("ℹ️ Session cleared from persistent storage")
    }

    /// Update auth state from a deep link session (e.g. invite or recovery)
    func applyDeepLinkSession(accessToken: String, refreshToken: String?, userId: String?, email: String?) {
        let claims = decodeJWTClaims(accessToken)
        if let userId {
            self.userId = userId
        } else if let sub = claims?["sub"] as? String {
            self.userId = sub
        }
        if let email {
            self.userEmail = email
        } else if let tokenEmail = claims?["email"] as? String {
            self.userEmail = tokenEmail
        }
        self.accessToken = accessToken
        if let refreshToken {
            self.refreshToken = refreshToken
        }
        self.isAuthenticated = true
        self.isGuest = false
        saveSession()
    }

    /// Validate and refresh session on app launch
    /// Returns true if session is valid, false if user needs to re-authenticate
    func validateSessionOnAppLaunch() async -> Bool {
        guard isAuthenticated, !isGuest, let _ = refreshToken else {
            return isAuthenticated
        }

        do {
            print("ℹ️ Validating session on app launch...")
            try await refreshAccessToken()
            print("✅ Session validated and refreshed")
            return true
        } catch {
            print("⚠️ Session validation failed: \(error.localizedDescription)")
            print("ℹ️ User will need to re-authenticate")
            // Don't clear session here - let user try using app first
            // Session will be cleared if they try to make API calls
            return false
        }
    }

    /// Decode JWT payload into a dictionary of claims
    private func decodeJWTClaims(_ jwt: String) -> [String: Any]? {
        let parts = jwt.split(separator: ".")
        guard parts.count >= 2 else { return nil }
        var base64 = parts[1].replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        while base64.count % 4 != 0 { base64.append("=") }
        guard let data = Data(base64Encoded: base64),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        return json
    }

    /// Refresh the access token using the refresh token
    /// Called when a 401 Unauthorized error is received
    /// Note: Does NOT log out user if refresh fails - only throws error
    /// Logout only happens explicitly via signOut() or on app restart
    func refreshAccessToken() async throws {
        guard let refreshToken = self.refreshToken else {
            throw NSError(domain: "NoRefreshToken", code: -1, userInfo: [NSLocalizedDescriptionKey: "No refresh token available"])
        }

        // Supabase requires grant_type as query parameter, not in request body
        var urlComponents = URLComponents(url: supabaseURL.appendingPathComponent("auth/v1/token"), resolvingAgainstBaseURL: false)!
        urlComponents.queryItems = [URLQueryItem(name: "grant_type", value: "refresh_token")]
        let url = urlComponents.url!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")

        struct RefreshBody: Encodable {
            let refresh_token: String
        }

        let body = RefreshBody(refresh_token: refreshToken)
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "InvalidResponse", code: -1)
        }

        if httpResponse.statusCode == 200 {
            do {
                let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)
                self.accessToken = tokenResponse.access_token
                self.refreshToken = tokenResponse.refresh_token
                self.saveSession()
                print("✅ Access token refreshed successfully")
            } catch {
                print("❌ Failed to decode token response: \(error)")
                // Throw error but don't log out - let caller decide what to do
                throw error
            }
        } else {
            // Refresh token is invalid or expired - throw error but don't log out yet
            // This allows the app to continue; logout will happen on next app launch if needed
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("⚠️ Token refresh failed (HTTP \(httpResponse.statusCode)): \(errorMessage)")
            throw NSError(domain: "TokenRefreshFailed", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Unable to refresh session. Please try again."])
        }
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
                    self.refreshToken = response.refresh_token
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

    /// Sign in via Google OAuth and exchange the ID token with Supabase
    func signInWithGoogle(presenting viewController: UIViewController) async throws {
        isLoading = true
        errorMessage = nil

        defer { isLoading = false }

        let configuredClientID = (Bundle.main.object(forInfoDictionaryKey: "GIDClientID") as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let clientID = configuredClientID?.isEmpty == false ? configuredClientID! : SupabaseConfig.googleClientID
        print("ℹ️ Google Sign-In configuredClientID (plist): \(configuredClientID ?? "nil")")
        print("ℹ️ Google Sign-In clientID (resolved): \(clientID)")

        guard !clientID.isEmpty,
              clientID != "REPLACE_WITH_YOUR_GOOGLE_CLIENT_ID" else {
            let message = "Set your Google client ID in SupabaseConfig.swift and Info.plist before using Google Sign-In."
            errorMessage = message
            throw NSError(domain: "GoogleAuth", code: -10, userInfo: [NSLocalizedDescriptionKey: message])
        }

        // Configure Google Sign-In
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)

        // Present Google sign-in flow
        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: viewController)

        guard let idToken = result.user.idToken?.tokenString else {
            let message = "Missing Google ID token from sign-in response."
            errorMessage = message
            throw NSError(domain: "GoogleAuth", code: -11, userInfo: [NSLocalizedDescriptionKey: message])
        }

        let decodedNonce = extractNonce(from: idToken)
        print("ℹ️ Google ID token nonce (decoded): \(decodedNonce ?? "nil")")

        try await exchangeGoogleIDTokenForSession(
            idToken: idToken,
            emailHint: result.user.profile?.email,
            nonce: decodedNonce
        )
    }

    /// Exchange a Google ID token for a Supabase session
    private func exchangeGoogleIDTokenForSession(idToken: String, emailHint: String?, nonce: String?) async throws {
        var urlComponents = URLComponents(url: supabaseURL.appendingPathComponent("auth/v1/token"), resolvingAgainstBaseURL: false)!
        urlComponents.queryItems = [URLQueryItem(name: "grant_type", value: "id_token")]
        let url = urlComponents.url!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")

        struct GoogleTokenBody: Encodable {
            let id_token: String
            let provider: String
            let nonce: String?
        }

        request.httpBody = try JSONEncoder().encode(GoogleTokenBody(id_token: idToken, provider: "google", nonce: nonce))

        print("ℹ️ Exchanging Google ID token with Supabase... (nonce present: \(nonce != nil))")
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "InvalidResponse", code: -1)
        }

        print("ℹ️ Supabase token exchange status: \(httpResponse.statusCode)")

        if httpResponse.statusCode == 200 {
            do {
                let response = try JSONDecoder().decode(TokenResponse.self, from: data)
                self.userId = response.user.id
                self.userEmail = response.user.email ?? emailHint
                self.accessToken = response.access_token
                self.refreshToken = response.refresh_token
                self.isAuthenticated = true
                self.saveSession()
                print("✅ User signed in with Google")
            } catch {
                print("⚠️ Could not parse Google token exchange response: \(error)")

                // Attempt a basic JSON parse to salvage the session
                guard let jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    let message = "Google sign-in succeeded but response could not be parsed."
                    errorMessage = message
                    throw NSError(domain: "GoogleAuth", code: -12, userInfo: [NSLocalizedDescriptionKey: message])
                }

                if let accessToken = jsonObject["access_token"] as? String {
                    self.accessToken = accessToken
                }

                if let userDict = jsonObject["user"] as? [String: Any],
                   let userId = userDict["id"] as? String {
                    self.userId = userId
                } else if let userId = jsonObject["user_id"] as? String {
                    self.userId = userId
                } else if let userId = jsonObject["id"] as? String {
                    self.userId = userId
                }

                self.userEmail = emailHint ?? self.userEmail
                self.isAuthenticated = self.accessToken != nil
                self.saveSession()
                print("✅ User signed in with Google (manual parse)")
            }
        } else {
            let errorData = String(data: data, encoding: .utf8) ?? "No error details"
            print("❌ Google token exchange failed: \(errorData)")

            let decodedError = try? JSONDecoder().decode(ErrorResponse.self, from: data)
            let message = decodedError?.message ??
                decodedError?.error_description ??
                decodedError?.error ??
                errorData

            errorMessage = "Google login failed: \(message)"
            throw NSError(domain: "AuthError", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: message])
        }
    }

    /// Extract nonce from a JWT (if present) without verification
    private func extractNonce(from idToken: String) -> String? {
        let parts = idToken.split(separator: ".")
        guard parts.count > 1 else { return nil }

        var base64 = String(parts[1])
        base64 = base64.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        while base64.count % 4 != 0 { base64.append("=") }

        guard let data = Data(base64Encoded: base64),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        return json["nonce"] as? String
    }

    /// Sign out the current user
    func signOut() async throws {
        isLoading = true
        errorMessage = nil

        defer { isLoading = false }

        let wasAuthenticated = self.isAuthenticated

        self.userId = nil
        self.userEmail = nil
        self.accessToken = nil
        self.isAuthenticated = false
        self.isGuest = false
        self.clearSession()  // Clear persisted session
        GIDSignIn.sharedInstance.signOut()

        // Only reset settings and clear data if user was authenticated
        // If user was in guest mode, preserve their local data
        if wasAuthenticated {
            print("ℹ️ Clearing data from authenticated session")
            AppSettingsManager.shared.resetToDefaults()
            SupabaseDataManager.shared.clearAllLocalData()
        } else {
            print("ℹ️ User was in guest mode - preserving local data")
        }

        print("✅ User signed out successfully")
    }

    /// Delete the current user's account
    /// This removes all data from the database and clears local session
    func deleteAccount() async throws {
        isLoading = true
        errorMessage = nil

        defer { isLoading = false }

        guard let userId = self.userId else {
            throw NSError(domain: "DeleteAccount", code: -1, userInfo: [NSLocalizedDescriptionKey: "User ID not found"])
        }

        guard let token = self.accessToken else {
            throw NSError(domain: "DeleteAccount", code: -1, userInfo: [NSLocalizedDescriptionKey: "Access token not found"])
        }

        do {
            // Delete all data from the database through SupabaseManager
            try await SupabaseManager.shared.deleteAccount(userId: userId, token: token)

            // Clear local session
            self.userId = nil
            self.userEmail = nil
            self.accessToken = nil
            self.isAuthenticated = false
            self.isGuest = false
            self.clearSession()
            GIDSignIn.sharedInstance.signOut()

            // Reset app data
            AppSettingsManager.shared.resetToDefaults()
            SupabaseDataManager.shared.clearAllLocalData()

            print("✅ Account deleted successfully")
        } catch {
            print("❌ Account deletion failed: \(error.localizedDescription)")
            throw error
        }
    }

    /// Continue as guest (no cloud sync, local-only settings)
    func continueAsGuest() {
        isLoading = true
        errorMessage = nil

        defer { isLoading = false }

        self.userId = nil
        self.userEmail = nil
        self.accessToken = nil
        self.isAuthenticated = false
        self.isGuest = true

        let defaults = UserDefaults.standard
        defaults.set(true, forKey: userDefaultsKeyIsGuest)

        // Note: Do NOT reset settings or clear local data here
        // Guests should be able to return to their local data across sessions
        // Settings will only be reset and data cleared when signing out from an authenticated session

        print("✅ User continuing as guest - settings will be local only")
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

    /// Update password using current authenticated session (used after recovery deep link)
    func updatePassword(newPassword: String) async throws {
        guard let accessToken = accessToken else {
            throw NSError(domain: "AuthError", code: -1, userInfo: [NSLocalizedDescriptionKey: "No access token available"])
        }

        let url = supabaseURL.appendingPathComponent("auth/v1/user")
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        struct UpdatePasswordBody: Encodable {
            let password: String
        }

        request.httpBody = try JSONEncoder().encode(UpdatePasswordBody(password: newPassword))

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "InvalidResponse", code: -1)
        }

        guard httpResponse.statusCode == 200 else {
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("❌ Failed to update password: \(message)")
            throw NSError(domain: "AuthError", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: message])
        }

        print("✅ Password updated successfully")
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
