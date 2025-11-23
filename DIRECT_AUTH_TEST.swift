import Foundation

/// Direct test of Supabase authentication endpoints
/// Use this to debug authentication issues without building the full app

let supabaseURL = "https://tzkspidmzlipujsnxpzc.supabase.co"
let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InR6a3NwaWRtemxpcHVqc254cHpjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjM4OTI2MTYsImV4cCI6MjA3OTQ2ODYxNn0.QMKZYMrESCOCT0KCHAKhPU995_mIB1F3l4Y4uq8s1uM"

// Test user credentials
let testEmail = "test@example.com"
let testPassword = "test123456"

print("=== Supabase Authentication Test ===\n")
print("Testing auth against: \(supabaseURL)\n")

// Test 1: Try signup
print("TEST 1: Signup with \(testEmail)")
print("Expected: 200 or 201 response with user ID")
print()

let signupURL = URL(string: "\(supabaseURL)/auth/v1/signup")!
var signupRequest = URLRequest(url: signupURL)
signupRequest.httpMethod = "POST"
signupRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
signupRequest.setValue(anonKey, forHTTPHeaderField: "apikey")

struct SignupBody: Codable {
    let email: String
    let password: String
}

let signupBody = SignupBody(email: testEmail, password: testPassword)
signupRequest.httpBody = try! JSONEncoder().encode(signupBody)

let signupSemaphore = DispatchSemaphore(value: 0)
var signupStatusCode: Int = -1

URLSession.shared.dataTask(with: signupRequest) { data, response, error in
    if let httpResponse = response as? HTTPURLResponse {
        signupStatusCode = httpResponse.statusCode
        print("Signup Response: HTTP \(httpResponse.statusCode)")
        if let data = data, let body = String(data: data, encoding: .utf8) {
            print("Response body: \(body)")
        }
    } else {
        print("Signup Error: \(error?.localizedDescription ?? "Unknown")")
    }
    signupSemaphore.signal()
}.resume()

signupSemaphore.wait()
print()

// Test 2: Try signin with token endpoint
print("TEST 2: Sign in with /auth/v1/token (with query param)")
print("URL: \(supabaseURL)/auth/v1/token?grant_type=password")
print("Expected: 200 response with access_token")
print()

let signinURL = URL(string: "\(supabaseURL)/auth/v1/token?grant_type=password")!
var signinRequest = URLRequest(url: signinURL)
signinRequest.httpMethod = "POST"
signinRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
signinRequest.setValue(anonKey, forHTTPHeaderField: "apikey")

struct SigninBody: Codable {
    let email: String
    let password: String
}

let signinBody = SigninBody(email: testEmail, password: testPassword)
signinRequest.httpBody = try! JSONEncoder().encode(signinBody)

let signinSemaphore = DispatchSemaphore(value: 0)
var signinStatusCode: Int = -1

URLSession.shared.dataTask(with: signinRequest) { data, response, error in
    if let httpResponse = response as? HTTPURLResponse {
        signinStatusCode = httpResponse.statusCode
        print("Sign-in Response: HTTP \(httpResponse.statusCode)")
        if let data = data, let body = String(data: data, encoding: .utf8) {
            print("Response body: \(body)")
        }
    } else {
        print("Sign-in Error: \(error?.localizedDescription ?? "Unknown")")
    }
    signinSemaphore.signal()
}.resume()

signinSemaphore.wait()
print()

// Test 3: Try signin with /auth/v1/signin endpoint
print("TEST 3: Sign in with /auth/v1/signin (alternative endpoint)")
print("Expected: 200 response")
print()

let signinAltURL = URL(string: "\(supabaseURL)/auth/v1/signin")!
var signinAltRequest = URLRequest(url: signinAltURL)
signinAltRequest.httpMethod = "POST"
signinAltRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
signinAltRequest.setValue(anonKey, forHTTPHeaderField: "apikey")
signinAltRequest.httpBody = try! JSONEncoder().encode(signinBody)

let signinAltSemaphore = DispatchSemaphore(value: 0)
var signinAltStatusCode: Int = -1

URLSession.shared.dataTask(with: signinAltRequest) { data, response, error in
    if let httpResponse = response as? HTTPURLResponse {
        signinAltStatusCode = httpResponse.statusCode
        print("Sign-in (alt) Response: HTTP \(httpResponse.statusCode)")
        if let data = data, let body = String(data: data, encoding: .utf8) {
            print("Response body: \(body)")
        }
    } else {
        print("Sign-in (alt) Error: \(error?.localizedDescription ?? "Unknown")")
    }
    signinAltSemaphore.signal()
}.resume()

signinAltSemaphore.wait()
print()

print("=== Summary ===")
print("Signup status: \(signupStatusCode)")
print("Sign-in (/token) status: \(signinStatusCode)")
print("Sign-in (/signin) status: \(signinAltStatusCode)")
print()
print("If you see 400 errors, check:")
print("1. Email/password provider is enabled in Supabase settings")
print("2. No email verification required before login")
print("3. User account actually exists")
