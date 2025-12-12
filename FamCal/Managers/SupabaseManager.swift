//
//  SupabaseManager.swift
//  FamCal
//
//  Manages all Supabase database operations for family data
//

import Foundation

class SupabaseManager: @unchecked Sendable {
    static let shared = SupabaseManager()

    private let supabaseURL: URL
    private let anonKey: String
    private let authManager: SupabaseAuthManager

    init(authManager: SupabaseAuthManager? = nil) {
        self.supabaseURL = URL(string: SupabaseConfig.supabaseURL)!
        self.anonKey = SupabaseConfig.supabaseAnonKey
        self.authManager = authManager ?? SupabaseAuthManager.shared
    }

    // MARK: - Helper Methods

    private func makeRequest(
        _ method: String,
        path: String,
        queryItems: [URLQueryItem] = [],
        body: Encodable? = nil,
        userToken: String? = nil,
        extraHeaders: [String: String] = [:],
        isRetry: Bool = false
    ) async throws -> (data: Data, statusCode: Int) {
        let url = supabaseURL.appendingPathComponent(path)

        var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        if !queryItems.isEmpty {
            urlComponents.queryItems = queryItems
        }

        var request = URLRequest(url: urlComponents.url!)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        for (key, value) in extraHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }

        if let token = userToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let body = body {
            request.httpBody = try JSONEncoder().encode(body)
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "InvalidResponse", code: -1)
        }

        // Handle 401 Unauthorized - attempt token refresh and retry
        if httpResponse.statusCode == 401 && !isRetry && userToken != nil {
            do {
                print("🔄 Attempting to refresh expired token...")
                try await authManager.refreshAccessToken()
                print("✅ Token refreshed, retrying request...")

                // Retry the request with the new token from authManager
                let newToken: String? = await MainActor.run {
                    authManager.accessToken
                }

                // Retry the request with the new token
                return try await makeRequest(
                    method,
                    path: path,
                    queryItems: queryItems,
                    body: body,
                    userToken: newToken,
                    extraHeaders: extraHeaders,
                    isRetry: true
                )
            } catch {
                print("❌ Token refresh failed: \(error)")
                // Token refresh failed - user will need to re-authenticate on next app launch
                // For now, let the 401 error propagate so the caller can handle it gracefully
                // Do NOT log out the user here - they may continue using the app with stale token
            }
        }

        return (data, httpResponse.statusCode)
    }

    private func logErrorResponse(_ data: Data, statusCode: Int, operation: String) {
        if let errorString = String(data: data, encoding: .utf8) {
            print("❌ [\(operation)] HTTP \(statusCode): \(errorString)")
        }
    }

    // MARK: - DTOs

    struct ProfileDTO: Codable {
        let id: String
        let email: String?
        let family_id: String?
    }

    struct FamilyDTO: Codable {
        let id: String
        let owner_user_id: String
        let family_name: String?
    }

    // MARK: - Family Members

    func createFamilyMember(userId: String, name: String, colorHex: String, id: UUID? = nil, token: String? = nil) async throws -> FamilyMemberDTO {
        let userToken = token ?? authManager.accessToken

        // Fetch profile to get family_id so the row is visible under family-scoped RLS
        let familyId: String
        if let profile = try? await getProfile(userId: userId, token: userToken), let fid = profile.family_id {
            familyId = fid
        } else if let family = try? await getFamilyForOwner(userId: userId, token: userToken) {
            familyId = family.id
        } else {
            throw NSError(domain: "CreateFamilyMember", code: -1, userInfo: [NSLocalizedDescriptionKey: "Missing family_id (no profile/family found). Please ensure profiles.family_id is set for the owner."])
        }

        // Check if member already exists in this family before attempting creation
        let queryItems = [
            URLQueryItem(name: "family_id", value: "eq.\(familyId)"),
            URLQueryItem(name: "name", value: "eq.\(name)")
        ]
        let (checkData, checkStatusCode) = try await makeRequest("GET", path: "rest/v1/family_members", queryItems: queryItems, userToken: userToken)

        if checkStatusCode == 200 {
            let members = try JSONDecoder().decode([FamilyMemberDTO].self, from: checkData)
            if let existingMember = members.first {
                print("ℹ️ Family member '\(name)' already exists in family, returning existing member...")
                return existingMember
            }
        }

        var body: [String: String] = [
            "user_id": userId,
            "family_id": familyId,
            "name": name,
            "color_hex": colorHex
        ]
        
        if let id = id {
            body["id"] = id.uuidString
        }

        let (data, statusCode) = try await makeRequest("POST", path: "rest/v1/family_members", body: body, userToken: userToken)

        guard statusCode == 201 else {
            logErrorResponse(data, statusCode: statusCode, operation: "createFamilyMember")

            // If we got 409 (conflict), try to fetch and return the existing member
            if statusCode == 409 {
                if let errorResponse = String(data: data, encoding: .utf8) {
                    print("ℹ️ 409 Conflict details: \(errorResponse)")
                    if errorResponse.contains("unique") || errorResponse.contains("family_member") {
                        print("⚠️ Family member '\(name)' already exists in this family.")
                        // Try fetching the existing member
                        let (fetchData, fetchStatusCode) = try await makeRequest("GET", path: "rest/v1/family_members", queryItems: queryItems, userToken: userToken)
                        if fetchStatusCode == 200 {
                            let members = try JSONDecoder().decode([FamilyMemberDTO].self, from: fetchData)
                            if let existingMember = members.first {
                                print("ℹ️ Returning existing family member...")
                                return existingMember
                            }
                        }
                    }
                }
            }

            throw NSError(domain: "CreateFamilyMember", code: statusCode)
        }

        // If response has data, decode it directly; otherwise fetch by name
        if !data.isEmpty {
            let createdMembers = try JSONDecoder().decode([FamilyMemberDTO].self, from: data)
            guard let createdMember = createdMembers.first else {
                throw NSError(domain: "CreateFamilyMember", code: -1, userInfo: [NSLocalizedDescriptionKey: "Created member not found in response"])
            }
            return createdMember
        } else {
            // Empty response - fetch the newly created member by name and family_id
            print("ℹ️ Empty response from createFamilyMember, fetching created member by name...")
            let (fetchData, fetchStatusCode) = try await makeRequest("GET", path: "rest/v1/family_members", queryItems: queryItems, userToken: userToken)

            guard fetchStatusCode == 200 else {
                throw NSError(domain: "CreateFamilyMember", code: fetchStatusCode, userInfo: [NSLocalizedDescriptionKey: "Failed to fetch created member"])
            }

            let members = try JSONDecoder().decode([FamilyMemberDTO].self, from: fetchData)
            guard let createdMember = members.first else {
                throw NSError(domain: "CreateFamilyMember", code: -1, userInfo: [NSLocalizedDescriptionKey: "Created member not found after creation"])
            }
            return createdMember
        }
    }

    func getFamilyMember(id: String, token: String? = nil) async throws -> FamilyMemberDTO? {
        let queryItems = [URLQueryItem(name: "id", value: "eq.\(id)")]
        let userToken = token ?? authManager.accessToken
        let (data, statusCode) = try await makeRequest("GET", path: "rest/v1/family_members", queryItems: queryItems, userToken: userToken)

        guard statusCode == 200 else {
            logErrorResponse(data, statusCode: statusCode, operation: "getFamilyMember")
            throw NSError(domain: "GetFamilyMember", code: statusCode)
        }

        let members = try JSONDecoder().decode([FamilyMemberDTO].self, from: data)
        return members.first
    }

    func getProfile(userId: String, token: String? = nil) async throws -> ProfileDTO {
        let queryItems = [URLQueryItem(name: "id", value: "eq.\(userId)")]
        let userToken = token ?? authManager.accessToken
        let (data, statusCode) = try await makeRequest("GET", path: "rest/v1/profiles", queryItems: queryItems, userToken: userToken)

        guard statusCode == 200 else {
            logErrorResponse(data, statusCode: statusCode, operation: "getProfile")
            throw NSError(domain: "GetProfile", code: statusCode)
        }

        let profiles = try JSONDecoder().decode([ProfileDTO].self, from: data)
        guard let profile = profiles.first else {
            throw NSError(domain: "GetProfile", code: -1, userInfo: [NSLocalizedDescriptionKey: "Profile not found"])
        }
        return profile
    }

    /// Fetch multiple profiles by user ids
    func getProfiles(userIds: [String], token: String? = nil) async throws -> [ProfileDTO] {
        guard !userIds.isEmpty else { return [] }
        let ids = userIds.joined(separator: ",")
        let queryItems = [URLQueryItem(name: "id", value: "in.(\(ids))")]
        let userToken = token ?? authManager.accessToken
        let (data, statusCode) = try await makeRequest("GET", path: "rest/v1/profiles", queryItems: queryItems, userToken: userToken)

        guard statusCode == 200 else {
            logErrorResponse(data, statusCode: statusCode, operation: "getProfiles")
            throw NSError(domain: "GetProfiles", code: statusCode)
        }

        return try JSONDecoder().decode([ProfileDTO].self, from: data)
    }

    /// Update current user's profile with family_id
    func updateProfileFamilyId(familyId: String, token: String? = nil) async throws {
        let userToken = token ?? authManager.accessToken

        guard let userId = await MainActor.run(body: { authManager.userId }) else {
            throw NSError(domain: "UpdateProfile", code: -1, userInfo: [NSLocalizedDescriptionKey: "User ID not available"])
        }

        struct UpdateBody: Encodable {
            let family_id: String
        }

        let body = UpdateBody(family_id: familyId)
        let queryItems = [URLQueryItem(name: "id", value: "eq.\(userId)")]
        let (data, statusCode) = try await makeRequest("PATCH", path: "rest/v1/profiles", queryItems: queryItems, body: body, userToken: userToken)

        // Supabase may return 200 with row or 204 with empty body on PATCH
        guard statusCode == 200 || statusCode == 204 else {
            logErrorResponse(data, statusCode: statusCode, operation: "updateProfileFamilyId")
            throw NSError(domain: "UpdateProfile", code: statusCode)
        }

        print("✅ Profile family_id updated successfully")
    }

    struct MemberEmailDTO: Codable {
        let family_member_id: String
        let email: String?
    }

    /// Fetch linked emails for members in the current user's family via service-role edge function.
    func getMemberEmailsForFamily() async throws -> [MemberEmailDTO] {
        guard let userToken = authManager.accessToken else {
            throw NSError(domain: "GetMemberEmails", code: -1, userInfo: [NSLocalizedDescriptionKey: "Missing access token"])
        }

        var headers: [String: String] = [:]
        if !SupabaseConfig.inviteFunctionKey.isEmpty {
            headers["x-invite-fn-key"] = SupabaseConfig.inviteFunctionKey
        }

        let (data, statusCode) = try await makeRequest(
            "GET",
            path: "functions/v1/member-emails",
            userToken: userToken,
            extraHeaders: headers
        )

        guard statusCode == 200 else {
            logErrorResponse(data, statusCode: statusCode, operation: "getMemberEmailsForFamily")
            throw NSError(domain: "GetMemberEmails", code: statusCode)
        }

        struct Response: Codable { let emails: [MemberEmailDTO] }
        let decoded = try JSONDecoder().decode(Response.self, from: data)
        return decoded.emails
    }

    func getFamilyForOwner(userId: String, token: String? = nil) async throws -> FamilyDTO? {
        let queryItems = [URLQueryItem(name: "owner_user_id", value: "eq.\(userId)")]
        let userToken = token ?? authManager.accessToken
        let (data, statusCode) = try await makeRequest("GET", path: "rest/v1/families", queryItems: queryItems, userToken: userToken)

        guard statusCode == 200 else {
            logErrorResponse(data, statusCode: statusCode, operation: "getFamilyForOwner")
            throw NSError(domain: "GetFamilyForOwner", code: statusCode)
        }

        let families = try JSONDecoder().decode([FamilyDTO].self, from: data)
        return families.first
    }

    /// Resolve the family_id assigned to the given user, using their profile or owner record.
    func getFamilyIdForUser(userId: String, token: String? = nil) async throws -> String {
        if let cachedFamilyId = AppSettingsManager.shared.familyId {
            print("🔎 Using cached family_id \(cachedFamilyId) from AppSettingsManager")
            return cachedFamilyId
        }

        guard let userToken = token ?? authManager.accessToken else {
            throw NSError(domain: "ResolveFamilyId", code: -1, userInfo: [NSLocalizedDescriptionKey: "Missing access token"])
        }

        do {
            let profile = try await getProfile(userId: userId, token: userToken)
            if let familyId = profile.family_id {
                print("🔎 Resolved family_id \(familyId) for user \(userId) via profile")
                return familyId
            }
        } catch {
            print("⚠️ Unable to load profile for user \(userId): \(error)")
        }

        if let family = try? await getCurrentFamily(token: userToken) {
            print("🔎 Resolved family_id \(family.id) for user \(userId) via accessible family lookup")
            return family.id
        }

        if let family = try? await getFamilyForOwner(userId: userId, token: userToken) {
            print("🔎 Resolved family_id \(family.id) for user \(userId) via owner lookup")
            return family.id
        }

        throw NSError(domain: "ResolveFamilyId", code: -1, userInfo: [NSLocalizedDescriptionKey: "No family found for user \(userId)"])
    }

    /// Fetch the current family (first accessible row)
    func getCurrentFamily(token: String? = nil) async throws -> FamilyDTO? {
        let userToken = token ?? authManager.accessToken
        let (data, statusCode) = try await makeRequest("GET", path: "rest/v1/families", userToken: userToken)

        guard statusCode == 200 else {
            logErrorResponse(data, statusCode: statusCode, operation: "getCurrentFamily")
            throw NSError(domain: "GetFamily", code: statusCode)
        }

        let families = try JSONDecoder().decode([FamilyDTO].self, from: data)
        return families.first
    }

    /// Create a new family (owner only), or return existing family if it already exists
    func createFamily(ownerUserId: String, familyName: String? = nil, token: String? = nil) async throws -> FamilyDTO {
        let userToken = token ?? authManager.accessToken

        // First, check if a family already exists for this owner
        if let existingFamily = try? await getFamilyForOwner(userId: ownerUserId, token: userToken) {
            print("ℹ️ Family already exists for owner: \(existingFamily.id)")

            // Update the family name if provided and different
            let trimmedName = familyName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !trimmedName.isEmpty && trimmedName != (existingFamily.family_name ?? "") {
                try await updateFamilyName(familyId: existingFamily.id, name: trimmedName, token: userToken)
                print("✅ Updated existing family name to: \(trimmedName)")
            }

            return existingFamily
        }

        struct CreateBody: Encodable {
            let owner_user_id: String
            let family_name: String
        }

        let body = CreateBody(
            owner_user_id: ownerUserId,
            family_name: familyName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        )

        let (data, statusCode) = try await makeRequest("POST", path: "rest/v1/families", body: body, userToken: userToken)

        guard statusCode == 201 else {
            logErrorResponse(data, statusCode: statusCode, operation: "createFamily")
            throw NSError(domain: "CreateFamily", code: statusCode)
        }

        // Handle empty response body (Supabase returns 201 with empty body without Prefer header)
        if data.isEmpty {
            print("ℹ️ Supabase returned empty body (201), fetching created family...")
            if let createdFamily = try? await getFamilyForOwner(userId: ownerUserId, token: userToken) {
                print("✅ Family created successfully: \(createdFamily.id)")
                return createdFamily
            } else {
                throw NSError(domain: "CreateFamily", code: -1, userInfo: [NSLocalizedDescriptionKey: "Family created but could not be retrieved"])
            }
        }

        do {
            let family = try JSONDecoder().decode(FamilyDTO.self, from: data)
            print("✅ Family created successfully: \(family.id)")
            return family
        } catch {
            print("❌ Failed to decode family response: \(error)")
            // Try to fetch the family if decoding fails
            if let createdFamily = try? await getFamilyForOwner(userId: ownerUserId, token: userToken) {
                print("✅ Family created (recovered via fetch): \(createdFamily.id)")
                return createdFamily
            }
            throw error
        }
    }

    /// Update family name (owner only)
    func updateFamilyName(familyId: String, name: String, token: String? = nil) async throws {
        struct UpdateBody: Encodable { let family_name: String }
        let userToken = token ?? authManager.accessToken
        let body = UpdateBody(family_name: name)
        let queryItems = [URLQueryItem(name: "id", value: "eq.\(familyId)")]
        let (data, statusCode) = try await makeRequest("PATCH", path: "rest/v1/families", queryItems: queryItems, body: body, userToken: userToken)

        // Supabase may return 200 with row or 204 with empty body on PATCH
        guard statusCode == 200 || statusCode == 204 else {
            logErrorResponse(data, statusCode: statusCode, operation: "updateFamilyName")
            throw NSError(domain: "UpdateFamily", code: statusCode)
        }
    }

    func getFamilyMembers(userId: String, token: String? = nil) async throws -> [FamilyMemberDTO] {
        // Fetch family members for the current user's family
        // Filter by family_id to ensure we only get members from the user's family
        let userToken = token ?? authManager.accessToken

        // Get the user's family to get the family_id
        // Try cached family_id first (important for newly invited users whose profile might not be updated yet)
        let familyId: String
        if let cachedFamilyId = AppSettingsManager.shared.familyId {
            familyId = cachedFamilyId
            print("🔎 Using cached family_id \(cachedFamilyId) for getFamilyMembers")
        } else {
            familyId = try await getFamilyIdForUser(userId: userId, token: userToken)
        }

        let queryItems = [URLQueryItem(name: "family_id", value: "eq.\(familyId)")]
        let (data, statusCode) = try await makeRequest("GET", path: "rest/v1/family_members", queryItems: queryItems, userToken: userToken)

        guard statusCode == 200 else {
            logErrorResponse(data, statusCode: statusCode, operation: "getFamilyMembers")
            throw NSError(domain: "GetFamilyMembers", code: statusCode)
        }

        return try JSONDecoder().decode([FamilyMemberDTO].self, from: data)
    }

    func isUserLinkedToFamily(userId: String, familyId: String, token: String? = nil) async throws -> Bool {
        let userToken = token ?? authManager.accessToken
        let queryItems = [
            URLQueryItem(name: "family_id", value: "eq.\(familyId)"),
            URLQueryItem(name: "linked_user_id", value: "eq.\(userId)")
        ]
        let (data, statusCode) = try await makeRequest("GET", path: "rest/v1/family_members", queryItems: queryItems, userToken: userToken)

        guard statusCode == 200 else {
            logErrorResponse(data, statusCode: statusCode, operation: "isUserLinkedToFamily")
            throw NSError(domain: "IsUserLinkedToFamily", code: statusCode)
        }

        let members = try JSONDecoder().decode([FamilyMemberDTO].self, from: data)
        return !members.isEmpty
    }

    func updateFamilyMember(id: String, name: String, colorHex: String, token: String? = nil) async throws {
        let body: [String: String] = [
            "name": name,
            "color_hex": colorHex
        ]

        let queryItems = [URLQueryItem(name: "id", value: "eq.\(id)")]
        let userToken = token ?? authManager.accessToken
        let (_, statusCode) = try await makeRequest("PATCH", path: "rest/v1/family_members", queryItems: queryItems, body: body, userToken: userToken)

        guard statusCode == 200 else {
            throw NSError(domain: "UpdateFamilyMember", code: statusCode)
        }
    }

    /// Update the driver status for a family member.
    func updateFamilyMemberDriver(memberId: String, isDriver: Bool, token: String? = nil) async throws {
        let body: [String: Bool] = [
            "is_driver": isDriver
        ]

        let queryItems = [URLQueryItem(name: "id", value: "eq.\(memberId)")]
        let userToken = token ?? authManager.accessToken
        let (data, statusCode) = try await makeRequest("PATCH", path: "rest/v1/family_members", queryItems: queryItems, body: body, userToken: userToken)

        guard (200...299).contains(statusCode) else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("⚠️ Supabase update family member driver response (status: \(statusCode)): \(errorMessage)")
            throw NSError(domain: "UpdateFamilyMemberDriver", code: statusCode, userInfo: [NSLocalizedDescriptionKey: errorMessage])
        }
    }

    /// Link the current authenticated user to a family member (sets linked_user_id).
    func linkCurrentUserToFamilyMember(id: String, token: String? = nil) async throws {
        guard let userId = authManager.userId else {
            throw NSError(domain: "LinkFamilyMember", code: -1, userInfo: [NSLocalizedDescriptionKey: "Missing user id"])
        }

        let body = LinkedUserUpdate(linked_user_id: userId)

        let queryItems = [URLQueryItem(name: "id", value: "eq.\(id)")]
        let userToken = token ?? authManager.accessToken
        let (data, statusCode) = try await makeRequest("PATCH", path: "rest/v1/family_members", queryItems: queryItems, body: body, userToken: userToken)

        guard (200...299).contains(statusCode) else {
            logErrorResponse(data, statusCode: statusCode, operation: "linkCurrentUserToFamilyMember")
            throw NSError(domain: "LinkFamilyMember", code: statusCode)
        }
    }

    /// Remove linked_user_id for all members in a family (without deleting members).
    func unlinkFamilyMembers(familyId: String, token: String? = nil) async throws {
        let body: [String: AnyCodable] = ["linked_user_id": .null] // force explicit null
        let queryItems = [URLQueryItem(name: "family_id", value: "eq.\(familyId)")]
        let userToken = token ?? authManager.accessToken
        let (data, statusCode) = try await makeRequest("PATCH", path: "rest/v1/family_members", queryItems: queryItems, body: body, userToken: userToken)

        guard (200...299).contains(statusCode) else {
            logErrorResponse(data, statusCode: statusCode, operation: "unlinkFamilyMembers")
            throw NSError(domain: "UnlinkFamilyMember", code: statusCode)
        }
    }

    /// Remove linked_user_id for members linked to the current user, optionally scoped to a family.
    func unlinkCurrentUserFromFamilyMembers(familyId: String? = nil, token: String? = nil) async throws {
        guard let userId = authManager.userId else {
            throw NSError(domain: "UnlinkFamilyMember", code: -1, userInfo: [NSLocalizedDescriptionKey: "Missing user id"])
        }

        var queryItems = [URLQueryItem(name: "linked_user_id", value: "eq.\(userId)")]
        if let familyId {
            queryItems.append(URLQueryItem(name: "family_id", value: "eq.\(familyId)"))
        }

        let body: [String: AnyCodable] = ["linked_user_id": .null] // force explicit null
        let userToken = token ?? authManager.accessToken
        let (data, statusCode) = try await makeRequest("PATCH", path: "rest/v1/family_members", queryItems: queryItems, body: body, userToken: userToken)

        guard (200...299).contains(statusCode) else {
            logErrorResponse(data, statusCode: statusCode, operation: "unlinkCurrentUserFromFamilyMembers")
            throw NSError(domain: "UnlinkFamilyMember", code: statusCode)
        }
    }

    /// Remove linked_user_id from a specific family member by ID.
    func unlinkSpecificMember(memberId: String, token: String? = nil) async throws {
        let queryItems = [URLQueryItem(name: "id", value: "eq.\(memberId)")]
        let body: [String: AnyCodable] = ["linked_user_id": .null] // force explicit null
        let userToken = token ?? authManager.accessToken
        let (data, statusCode) = try await makeRequest("PATCH", path: "rest/v1/family_members", queryItems: queryItems, body: body, userToken: userToken)

        guard (200...299).contains(statusCode) else {
            logErrorResponse(data, statusCode: statusCode, operation: "unlinkSpecificMember")
            throw NSError(domain: "UnlinkMember", code: statusCode)
        }
    }

    /// Clear any linked_user_id in the family and any rows linked to the current user, then link the new member.
    func relinkCurrentUser(to memberId: String, familyId: String?, token: String? = nil) async throws {
        // 1) Clear any existing links for this user across all families (do not rely on linked_user_id for membership)
        try await unlinkCurrentUserFromFamilyMembers(token: token)

        // 2) Clear any linked_user_id values within the target family (keeps members; only nulls the link)
        if let familyId {
            try await unlinkFamilyMembers(familyId: familyId, token: token)
        }

        // 3) Link to the target member
        try await linkCurrentUserToFamilyMember(id: memberId, token: token)
    }

    private struct LinkedUserUpdate: Encodable {
        let linked_user_id: String?
    }

    /// Delete the current user's account and all associated data
    /// This includes: profile, family members, calendars, events, and settings
    func deleteAccount(userId: String, token: String? = nil) async throws {
        guard !userId.isEmpty else {
            throw NSError(domain: "DeleteAccount", code: -1, userInfo: [NSLocalizedDescriptionKey: "Missing user ID"])
        }

        let userToken = token ?? authManager.accessToken
        guard userToken != nil else {
            throw NSError(domain: "DeleteAccount", code: -1, userInfo: [NSLocalizedDescriptionKey: "Missing access token"])
        }

        // Note: Deletion follows foreign key constraints and cascading deletes configured in Supabase
        // The order matters: delete from tables with no dependencies first, then work up to tables with dependencies

        // 1. Delete personal calendars (no dependencies)
        try await deleteUserPersonalCalendars(userId: userId, token: userToken)

        // 2. Delete saved addresses (no dependencies)
        try await deleteUserSavedAddresses(userId: userId, token: userToken)

        // 3. Delete drivers (references family members, but will cascade)
        try await deleteUserDrivers(userId: userId, token: userToken)

        // 4. Delete app settings (references user, no cascade needed)
        try await deleteUserAppSettings(userId: userId, token: userToken)

        // 5. Delete shared calendars owned by user (many-to-many with family members)
        try await deleteUserSharedCalendars(userId: userId, token: userToken)

        // 6. Delete family member calendars (references family members)
        try await deleteUserFamilyMemberCalendars(userId: userId, token: userToken)

        // 7. Delete family members created by user
        try await deleteUserFamilyMembers(userId: userId, token: userToken)

        // 8. Delete families owned by user (cascades to any remaining members)
        try await deleteUserFamilies(userId: userId, token: userToken)

        // 9. Delete profile (references families and auth.users)
        try await deleteUserProfile(userId: userId, token: userToken)

        // 10. Delete the auth user itself via edge function
        try await deleteAuthUser(token: userToken)

        print("✅ Account deleted successfully for user: \(userId)")
    }

    private func deleteUserPersonalCalendars(userId: String, token: String? = nil) async throws {
        let queryItems = [URLQueryItem(name: "user_id", value: "eq.\(userId)")]
        let (_, statusCode) = try await makeRequest("DELETE", path: "rest/v1/personal_calendars", queryItems: queryItems, userToken: token)

        guard statusCode == 204 else {
            print("⚠️ Failed to delete personal calendars (HTTP \(statusCode))")
            return
        }
    }

    private func deleteUserSavedAddresses(userId: String, token: String? = nil) async throws {
        let queryItems = [URLQueryItem(name: "user_id", value: "eq.\(userId)")]
        let (_, statusCode) = try await makeRequest("DELETE", path: "rest/v1/saved_addresses", queryItems: queryItems, userToken: token)

        guard statusCode == 204 else {
            print("⚠️ Failed to delete saved addresses (HTTP \(statusCode))")
            return
        }
    }

    private func deleteUserDrivers(userId: String, token: String? = nil) async throws {
        let queryItems = [URLQueryItem(name: "user_id", value: "eq.\(userId)")]
        let (_, statusCode) = try await makeRequest("DELETE", path: "rest/v1/drivers", queryItems: queryItems, userToken: token)

        guard statusCode == 204 else {
            print("⚠️ Failed to delete drivers (HTTP \(statusCode))")
            return
        }
    }

    private func deleteUserAppSettings(userId: String, token: String? = nil) async throws {
        let queryItems = [URLQueryItem(name: "user_id", value: "eq.\(userId)")]
        let (_, statusCode) = try await makeRequest("DELETE", path: "rest/v1/app_settings", queryItems: queryItems, userToken: token)

        guard statusCode == 204 else {
            print("⚠️ Failed to delete app settings (HTTP \(statusCode))")
            return
        }
    }

    private func deleteUserSharedCalendars(userId: String, token: String? = nil) async throws {
        let queryItems = [URLQueryItem(name: "user_id", value: "eq.\(userId)")]
        let (_, statusCode) = try await makeRequest("DELETE", path: "rest/v1/shared_calendars", queryItems: queryItems, userToken: token)

        guard statusCode == 204 else {
            print("⚠️ Failed to delete shared calendars (HTTP \(statusCode))")
            return
        }
    }

    private func deleteUserFamilyMemberCalendars(userId: String, token: String? = nil) async throws {
        // Delete family member calendars where the associated family member was created by this user
        let queryItems = [URLQueryItem(name: "user_id", value: "eq.\(userId)")]
        let (_, statusCode) = try await makeRequest("DELETE", path: "rest/v1/family_member_calendars", queryItems: queryItems, userToken: token)

        guard statusCode == 204 else {
            print("⚠️ Failed to delete family member calendars (HTTP \(statusCode))")
            return
        }
    }

    private func deleteUserFamilyMembers(userId: String, token: String? = nil) async throws {
        let queryItems = [URLQueryItem(name: "user_id", value: "eq.\(userId)")]
        let (_, statusCode) = try await makeRequest("DELETE", path: "rest/v1/family_members", queryItems: queryItems, userToken: token)

        guard statusCode == 204 else {
            print("⚠️ Failed to delete family members (HTTP \(statusCode))")
            return
        }
    }

    private func deleteUserFamilies(userId: String, token: String? = nil) async throws {
        let queryItems = [URLQueryItem(name: "owner_user_id", value: "eq.\(userId)")]
        let (_, statusCode) = try await makeRequest("DELETE", path: "rest/v1/families", queryItems: queryItems, userToken: token)

        guard statusCode == 204 else {
            print("⚠️ Failed to delete families (HTTP \(statusCode))")
            return
        }
    }

    private func deleteUserProfile(userId: String, token: String? = nil) async throws {
        let queryItems = [URLQueryItem(name: "id", value: "eq.\(userId)")]
        let (_, statusCode) = try await makeRequest("DELETE", path: "rest/v1/profiles", queryItems: queryItems, userToken: token)

        guard statusCode == 204 else {
            throw NSError(domain: "DeleteProfile", code: statusCode, userInfo: [NSLocalizedDescriptionKey: "Failed to delete user profile"])
        }
    }

    private func deleteAuthUser(token: String? = nil) async throws {
        // Call the delete-account edge function to delete the auth user
        // This requires the service role key which the function has access to
        let userToken = token ?? authManager.accessToken
        guard userToken != nil else {
            throw NSError(domain: "DeleteAuthUser", code: -1, userInfo: [NSLocalizedDescriptionKey: "Missing access token"])
        }

        var headers: [String: String] = [:]
        if !SupabaseConfig.deleteAccountFunctionKey.isEmpty {
            headers["x-delete-account-fn-key"] = SupabaseConfig.deleteAccountFunctionKey
        }

        let (data, statusCode) = try await makeRequest(
            "POST",
            path: "functions/v1/delete-account",
            body: EmptyBody(),
            userToken: userToken,
            extraHeaders: headers
        )

        guard statusCode == 200 else {
            if let errorString = String(data: data, encoding: .utf8) {
                print("❌ [deleteAuthUser] HTTP \(statusCode): \(errorString)")
            }
            throw NSError(domain: "DeleteAuthUser", code: statusCode, userInfo: [NSLocalizedDescriptionKey: "Failed to delete authentication account"])
        }

        print("✅ Auth user deleted successfully")
    }

    private struct EmptyBody: Encodable {}

    func deleteFamilyMember(id: String, token: String? = nil) async throws {
        let queryItems = [URLQueryItem(name: "id", value: "eq.\(id)")]
        let userToken = token ?? authManager.accessToken
        let (_, statusCode) = try await makeRequest("DELETE", path: "rest/v1/family_members", queryItems: queryItems, userToken: userToken)

        guard statusCode == 204 else {
            throw NSError(domain: "DeleteFamilyMember", code: statusCode)
        }
    }

    // MARK: - Invitations

    /// Call Edge Function to create an invitation and send email.
    func createFamilyInvitation(familyMemberId: UUID, inviteeEmail: String) async throws {
        struct InviteBody: Encodable {
            let family_member_id: UUID
            let invitee_email: String
        }

        guard let userToken = authManager.accessToken else {
            throw NSError(domain: "CreateInvitation", code: -1, userInfo: [NSLocalizedDescriptionKey: "Missing access token"])
        }

        let body = InviteBody(family_member_id: familyMemberId, invitee_email: inviteeEmail)
        var headers: [String: String] = [:]
        if !SupabaseConfig.inviteFunctionKey.isEmpty {
            headers["x-invite-fn-key"] = SupabaseConfig.inviteFunctionKey
        }
        let (data, statusCode) = try await makeRequest(
            "POST",
            path: "functions/v1/invite-email",
            body: body,
            userToken: userToken,
            extraHeaders: headers
        )

        guard statusCode == 200 else {
            logErrorResponse(data, statusCode: statusCode, operation: "createFamilyInvitation")
            throw NSError(domain: "CreateInvitation", code: statusCode)
        }
    }

    /// Accept an invitation token via RPC.
    func acceptInvitation(token: String) async throws {
        struct AcceptBody: Encodable {
            let invite_token: String
        }

        guard let userToken = authManager.accessToken else {
            throw NSError(domain: "AcceptInvitation", code: -1, userInfo: [NSLocalizedDescriptionKey: "Missing access token"])
        }

        let body = AcceptBody(invite_token: token)
        let (data, statusCode) = try await makeRequest(
            "POST",
            path: "rest/v1/rpc/accept_family_invitation",
            body: body,
            userToken: userToken
        )

        guard statusCode == 200 else {
            logErrorResponse(data, statusCode: statusCode, operation: "acceptInvitation")
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(domain: "AcceptInvitation", code: statusCode, userInfo: [NSLocalizedDescriptionKey: message])
        }
    }

    /// Accept a pending invitation based on the authenticated user's email (service-role edge function).
    /// Returns the family_id for the accepted invitation.
    func acceptInvitationForCurrentUserEmail() async throws -> String? {
        guard let userToken = authManager.accessToken else {
            throw NSError(domain: "AcceptInvitationByEmail", code: -1, userInfo: [NSLocalizedDescriptionKey: "Missing access token"])
        }

        var headers: [String: String] = [:]
        if !SupabaseConfig.inviteFunctionKey.isEmpty {
            headers["x-invite-fn-key"] = SupabaseConfig.inviteFunctionKey
        }

        let (data, statusCode) = try await makeRequest(
            "POST",
            path: "functions/v1/accept-invite",
            userToken: userToken,
            extraHeaders: headers
        )

        guard statusCode == 200 else {
            logErrorResponse(data, statusCode: statusCode, operation: "acceptInvitationByEmail")
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(domain: "AcceptInvitationByEmail", code: statusCode, userInfo: [NSLocalizedDescriptionKey: message])
        }

        // Parse the family_id from the response
        do {
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let familyId = json["family_id"] as? String {
                return familyId
            }
        } catch {
            print("⚠️ Failed to parse family_id from acceptance response: \(error)")
        }

        return nil
    }

    // MARK: - Family Member Calendars

    func addFamilyMemberCalendar(memberId: String, calendarName: String, calendarColorHex: String, isAutoLinked: Bool, familyId: String? = nil, token: String? = nil) async throws {
        struct CalendarBody: Encodable {
            let family_member_id: String
            let family_id: String
            let calendar_name: String
            let calendar_color_hex: String
            let is_auto_linked: Bool
        }

        let resolvedFamilyId: String
        if let familyId {
            resolvedFamilyId = familyId
        } else if let member = try await getFamilyMember(id: memberId, token: token), let fid = member.family_id {
            resolvedFamilyId = fid
        } else {
            throw NSError(domain: "AddFamilyMemberCalendar", code: -1, userInfo: [NSLocalizedDescriptionKey: "Missing family_id for member \(memberId)"])
        }

        let body = CalendarBody(
            family_member_id: memberId,
            family_id: resolvedFamilyId,
            calendar_name: calendarName,
            calendar_color_hex: calendarColorHex,
            is_auto_linked: isAutoLinked
        )

        let userToken = token ?? authManager.accessToken
        let (_, statusCode) = try await makeRequest("POST", path: "rest/v1/family_member_calendars", body: body, userToken: userToken)

        guard statusCode == 201 else {
            throw NSError(domain: "AddFamilyMemberCalendar", code: statusCode)
        }
    }

    func getFamilyMemberCalendars(memberId: String, token: String? = nil) async throws -> [FamilyMemberCalendarDTO] {
        let queryItems = [URLQueryItem(name: "family_member_id", value: "eq.\(memberId)")]
        let userToken = token ?? authManager.accessToken
        let (data, statusCode) = try await makeRequest("GET", path: "rest/v1/family_member_calendars", queryItems: queryItems, userToken: userToken)

        guard statusCode == 200 else {
            throw NSError(domain: "GetFamilyMemberCalendars", code: statusCode)
        }

        return try JSONDecoder().decode([FamilyMemberCalendarDTO].self, from: data)
    }

    func deleteFamilyMemberCalendar(id: String, token: String? = nil) async throws {
        let queryItems = [URLQueryItem(name: "id", value: "eq.\(id)")]
        let userToken = token ?? authManager.accessToken
        let (_, statusCode) = try await makeRequest("DELETE", path: "rest/v1/family_member_calendars", queryItems: queryItems, userToken: userToken)

        guard statusCode == 204 else {
            throw NSError(domain: "DeleteFamilyMemberCalendar", code: statusCode)
        }
    }

    // MARK: - Shared Calendars

    /// Create a shared calendar with an explicit family_id (used during setup)
    /// Note: calendarId is stored as part of calendar_name for identification
    func createSharedCalendar(familyId: String, calendarId: String, calendarName: String, calendarColorHex: String, token: String? = nil) async throws -> SharedCalendarDTO {
        // Create a unique calendar name that includes the calendarId for identification
        // Format: "Calendar Name (calendar-id)"
        let uniqueCalendarName = "\(calendarName)"

        guard let userId = authManager.userId else {
            throw NSError(domain: "CreateSharedCalendar", code: -1, userInfo: [NSLocalizedDescriptionKey: "User ID not available"])
        }

        let body: [String: String] = [
            "user_id": userId,
            "family_id": familyId,
            "calendar_name": uniqueCalendarName,
            "calendar_color_hex": calendarColorHex
        ]

        let userToken = token ?? authManager.accessToken
        let (data, statusCode) = try await makeRequest("POST", path: "rest/v1/shared_calendars", body: body, userToken: userToken)

        guard statusCode == 201 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("⚠️ Supabase create shared calendar response (status: \(statusCode)): \(errorMessage)")
            throw NSError(domain: "CreateSharedCalendar", code: statusCode, userInfo: [NSLocalizedDescriptionKey: errorMessage])
        }

        // Handle empty response body
        if data.isEmpty {
            print("ℹ️ Supabase returned empty body (201), shared calendar created: \(calendarName)")
            // Return a placeholder since we can't parse empty response
            // The calendar will be fetched on next data sync
            return SharedCalendarDTO(
                id: UUID().uuidString,
                user_id: "",
                calendar_name: uniqueCalendarName,
                calendar_color_hex: calendarColorHex,
                created_at: nil
            )
        }

        let decoder = JSONDecoder()
        let createdCalendar = try decoder.decode(SharedCalendarDTO.self, from: data)
        print("✅ Shared calendar created: \(createdCalendar.calendar_name)")
        return createdCalendar
    }

    func addSharedCalendar(userId: String, calendarName: String, calendarColorHex: String, token: String? = nil) async throws -> SharedCalendarDTO {
        // Resolve family_id for shared visibility
        let familyId: String
        let profile = try? await getProfile(userId: userId, token: token)
        
        if let fid = profile?.family_id {
            print("ℹ️ Found family_id from profile: \(fid)")
            familyId = fid
        } else if let family = try? await getCurrentFamily(token: token) {
            print("ℹ️ Found family_id from current family: \(family.id)")
            familyId = family.id
        } else {
            print("❌ Could not resolve family_id from profile or current family. Profile family_id: \(String(describing: profile?.family_id))")
            throw NSError(domain: "AddSharedCalendar", code: -1, userInfo: [NSLocalizedDescriptionKey: "Missing family_id on profile or current family"])
        }

        if familyId.isEmpty {
             throw NSError(domain: "AddSharedCalendar", code: -1, userInfo: [NSLocalizedDescriptionKey: "Resolved family_id is empty"])
        }

        let body: [String: String] = [
            "user_id": userId,
            "family_id": familyId,
            "calendar_name": calendarName,
            "calendar_color_hex": calendarColorHex
        ]
        
        print("📤 Creating shared calendar with body: \(body)")

        let userToken = token ?? authManager.accessToken
        let (data, statusCode) = try await makeRequest("POST", path: "rest/v1/shared_calendars", body: body, userToken: userToken)

        guard statusCode == 201 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("⚠️ Supabase add response (status: \(statusCode)): \(errorMessage)")
            throw NSError(domain: "AddSharedCalendar", code: statusCode, userInfo: [NSLocalizedDescriptionKey: errorMessage])
        }

        // Try to parse the response, but handle empty body (Supabase POST without Prefer header returns empty)
        if data.isEmpty {
            // If response is empty, we still need to fetch the created record
            // For now, return a placeholder that will be refreshed by fetchUserData()
            print("ℹ️ Supabase returned empty body (201), calendar will be loaded on next sync")
            // Fetch shared calendars to get the newly created one
            let sharedCals = try await getSharedCalendars(userId: userId, token: userToken)
            guard let newCalendar = sharedCals.first(where: { $0.calendar_name == calendarName }) else {
                throw NSError(domain: "CalendarNotFound", code: -1)
            }
            return newCalendar
        }

        // Parse and return the created shared calendar
        let decoder = JSONDecoder()
        let createdCalendar = try decoder.decode(SharedCalendarDTO.self, from: data)
        return createdCalendar
    }

    func getSharedCalendars(userId: String, token: String? = nil) async throws -> [SharedCalendarDTO] {
        // RLS scopes to family_id; no explicit filter needed
        let userToken = token ?? authManager.accessToken
        let (data, statusCode) = try await makeRequest("GET", path: "rest/v1/shared_calendars", userToken: userToken)

        guard statusCode == 200 else {
            throw NSError(domain: "GetSharedCalendars", code: statusCode)
        }

        return try JSONDecoder().decode([SharedCalendarDTO].self, from: data)
    }

    func deleteSharedCalendar(id: String, userId: String? = nil, token: String? = nil) async throws {
        var queryItems: [URLQueryItem] = [URLQueryItem(name: "id", value: "eq.\(id)")]

        // If userId provided, add it to the filter for extra safety
        if let userId = userId {
            queryItems.append(URLQueryItem(name: "user_id", value: "eq.\(userId)"))
        }

        let userToken = token ?? authManager.accessToken
        let (data, statusCode) = try await makeRequest("DELETE", path: "rest/v1/shared_calendars", queryItems: queryItems, userToken: userToken)

        guard statusCode == 204 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("⚠️ Supabase delete response (status: \(statusCode)): \(errorMessage)")
            throw NSError(domain: "DeleteSharedCalendar", code: statusCode, userInfo: [NSLocalizedDescriptionKey: errorMessage])
        }
    }

    func updateSharedCalendar(id: String, calendarName: String, calendarColorHex: String, token: String? = nil) async throws {
        struct UpdateBody: Encodable {
            let calendar_name: String
            let calendar_color_hex: String
        }

        let body = UpdateBody(calendar_name: calendarName, calendar_color_hex: calendarColorHex)
        let queryItems = [URLQueryItem(name: "id", value: "eq.\(id)")]
        let userToken = token ?? authManager.accessToken
        let (data, statusCode) = try await makeRequest("PATCH", path: "rest/v1/shared_calendars", queryItems: queryItems, body: body, userToken: userToken)

        guard statusCode == 200 || statusCode == 204 else {
            logErrorResponse(data, statusCode: statusCode, operation: "updateSharedCalendar")
            throw NSError(domain: "UpdateSharedCalendar", code: statusCode)
        }
    }

    // MARK: - Personal Calendars

    func addPersonalCalendar(userId: String, calendarName: String, calendarColorHex: String, token: String? = nil) async throws -> PersonalCalendarDTO {
        struct CreateBody: Encodable {
            let user_id: String
            let calendar_name: String
            let calendar_color_hex: String
            let show_in_next: Bool
            let show_in_spotlight: Bool
            let show_in_upcoming: Bool
            let show_in_month: Bool
            let show_in_day: Bool
        }

        let body = CreateBody(
            user_id: userId,
            calendar_name: calendarName,
            calendar_color_hex: calendarColorHex,
            show_in_next: true,
            show_in_spotlight: true,
            show_in_upcoming: true,
            show_in_month: true,
            show_in_day: true
        )

        let userToken = token ?? authManager.accessToken
        let (data, statusCode) = try await makeRequest("POST", path: "rest/v1/personal_calendars", body: body, userToken: userToken)

        guard statusCode == 201 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("⚠️ Supabase add response (status: \(statusCode)): \(errorMessage)")
            throw NSError(domain: "AddPersonalCalendar", code: statusCode, userInfo: [NSLocalizedDescriptionKey: errorMessage])
        }

        // Try to parse the response, but handle empty body
        if data.isEmpty {
            print("ℹ️ Supabase returned empty body (201), calendar will be loaded on next sync")
            let personalCals = try await getPersonalCalendars(userId: userId, token: userToken)
            guard let newCalendar = personalCals.first(where: { $0.calendar_name == calendarName }) else {
                throw NSError(domain: "CalendarNotFound", code: -1)
            }
            return newCalendar
        }

        let decoder = JSONDecoder()
        let createdCalendar = try decoder.decode(PersonalCalendarDTO.self, from: data)
        return createdCalendar
    }

    func updatePersonalCalendarVisibility(
        id: String,
        userId: String,
        showInNext: Bool,
        showInSpotlight: Bool,
        showInUpcoming: Bool,
        showInMonth: Bool,
        showInDay: Bool,
        token: String? = nil
    ) async throws {
        struct UpdateBody: Encodable {
            let show_in_next: Bool
            let show_in_spotlight: Bool
            let show_in_upcoming: Bool
            let show_in_month: Bool
            let show_in_day: Bool
        }

        let body = UpdateBody(
            show_in_next: showInNext,
            show_in_spotlight: showInSpotlight,
            show_in_upcoming: showInUpcoming,
            show_in_month: showInMonth,
            show_in_day: showInDay
        )

        let queryItems = [
            URLQueryItem(name: "id", value: "eq.\(id)"),
            URLQueryItem(name: "user_id", value: "eq.\(userId)")
        ]

        let userToken = token ?? authManager.accessToken
        let (data, statusCode) = try await makeRequest(
            "PATCH",
            path: "rest/v1/personal_calendars",
            queryItems: queryItems,
            body: body,
            userToken: userToken
        )

        guard statusCode == 200 || statusCode == 204 else {
            logErrorResponse(data, statusCode: statusCode, operation: "updatePersonalCalendarVisibility")
            throw NSError(domain: "UpdatePersonalCalendarVisibility", code: statusCode)
        }
    }

    func getPersonalCalendars(userId: String, token: String? = nil) async throws -> [PersonalCalendarDTO] {
        let userToken = token ?? authManager.accessToken
        let (data, statusCode) = try await makeRequest("GET", path: "rest/v1/personal_calendars", userToken: userToken)

        guard statusCode == 200 else {
            throw NSError(domain: "GetPersonalCalendars", code: statusCode)
        }

        return try JSONDecoder().decode([PersonalCalendarDTO].self, from: data)
    }

    func deletePersonalCalendar(id: String, userId: String? = nil, token: String? = nil) async throws {
        var queryItems: [URLQueryItem] = [URLQueryItem(name: "id", value: "eq.\(id)")]

        if let userId = userId {
            queryItems.append(URLQueryItem(name: "user_id", value: "eq.\(userId)"))
        }

        let userToken = token ?? authManager.accessToken
        let (data, statusCode) = try await makeRequest("DELETE", path: "rest/v1/personal_calendars", queryItems: queryItems, userToken: userToken)

        guard statusCode == 204 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("⚠️ Supabase delete response (status: \(statusCode)): \(errorMessage)")
            throw NSError(domain: "DeletePersonalCalendar", code: statusCode, userInfo: [NSLocalizedDescriptionKey: errorMessage])
        }
    }

    // MARK: - App Settings

    func getAppSettings(userId: String, token: String? = nil) async throws -> AppSettingsDTO {
        let queryItems = [URLQueryItem(name: "user_id", value: "eq.\(userId)")]
        let userToken = token ?? authManager.accessToken
        let (data, statusCode) = try await makeRequest("GET", path: "rest/v1/app_settings", queryItems: queryItems, userToken: userToken)

        guard statusCode == 200 else {
            logErrorResponse(data, statusCode: statusCode, operation: "getAppSettings")
            throw NSError(domain: "GetAppSettings", code: statusCode)
        }

        let results = try JSONDecoder().decode([AppSettingsDTO].self, from: data)
        guard let settings = results.first else {
            throw NSError(domain: "AppSettingsNotFound", code: 404)
        }
        return settings
    }

    func createOrUpdateAppSettings(userId: String, settings: [String: AnyCodable], token: String? = nil) async throws {
        let body = AppSettingsCreateRequest(user_id: userId, settings: settings)

        let userToken = token ?? authManager.accessToken
        let (_, statusCode) = try await makeRequest("POST", path: "rest/v1/app_settings", body: body, userToken: userToken)

        guard statusCode == 201 else {
            throw NSError(domain: "CreateAppSettings", code: statusCode)
        }
    }

    func updateAppSettings(id: String, settings: [String: AnyCodable], token: String? = nil) async throws {
        let body = AppSettingsUpdateRequest(settings: settings)

        let queryItems = [URLQueryItem(name: "id", value: "eq.\(id)")]
        let userToken = token ?? authManager.accessToken
        let (_, statusCode) = try await makeRequest("PATCH", path: "rest/v1/app_settings", queryItems: queryItems, body: body, userToken: userToken)

        guard statusCode == 200 || statusCode == 204 else {
            throw NSError(domain: "UpdateAppSettings", code: statusCode)
        }
    }

    // MARK: - Drivers

    func getDrivers(userId: String, token: String? = nil) async throws -> [DriverDTO] {
        let queryItems = [URLQueryItem(name: "user_id", value: "eq.\(userId)")]
        let userToken = token ?? authManager.accessToken
        let (data, statusCode) = try await makeRequest("GET", path: "rest/v1/drivers", queryItems: queryItems, userToken: userToken)

        guard statusCode == 200 else {
            logErrorResponse(data, statusCode: statusCode, operation: "getDrivers")
            throw NSError(domain: "GetDrivers", code: statusCode)
        }

        return try JSONDecoder().decode([DriverDTO].self, from: data)
    }

    func createDriver(
        userId: String,
        name: String,
        phone: String?,
        email: String?,
        notes: String?,
        travelTimeMinutes: Int,
        familyMemberId: String?,
        familyId: String,
        id: String? = nil,
        token: String? = nil
    ) async throws {
        struct CreateDriverBody: Encodable {
            let user_id: String
            let name: String
            let phone: String?
            let email: String?
            let notes: String?
            let travel_time_minutes: Int
            let family_member_id: String?
            let family_id: String
            let id: String?
        }

        let body = CreateDriverBody(
            user_id: userId,
            name: name,
            phone: phone,
            email: email,
            notes: notes,
            travel_time_minutes: travelTimeMinutes,
            family_member_id: familyMemberId,
            family_id: familyId,
            id: id
        )

        let userToken = token ?? authManager.accessToken
        let (data, statusCode) = try await makeRequest("POST", path: "rest/v1/drivers", body: body, userToken: userToken)

        guard statusCode == 201 else {
            logErrorResponse(data, statusCode: statusCode, operation: "createDriver")
            throw NSError(domain: "CreateDriver", code: statusCode)
        }
    }

    func updateDriver(
        id: String,
        name: String,
        phone: String?,
        email: String?,
        notes: String?,
        travelTimeMinutes: Int,
        familyMemberId: String?,
        token: String? = nil
    ) async throws {
        struct UpdateDriverBody: Encodable {
            let name: String
            let phone: String?
            let notes: String?
            let travel_time_minutes: Int
            let family_member_id: String?
        }

        let body = UpdateDriverBody(
            name: name,
            phone: phone,
            notes: notes,
            travel_time_minutes: travelTimeMinutes,
            family_member_id: familyMemberId
        )

        let queryItems = [URLQueryItem(name: "id", value: "eq.\(id)")]
        let userToken = token ?? authManager.accessToken
        let (data, statusCode) = try await makeRequest("PATCH", path: "rest/v1/drivers", queryItems: queryItems, body: body, userToken: userToken)

        guard (200...299).contains(statusCode) else {
            logErrorResponse(data, statusCode: statusCode, operation: "updateDriver")
            throw NSError(domain: "UpdateDriver", code: statusCode)
        }
    }

    func deleteDriver(id: String, token: String? = nil) async throws {
        let queryItems = [URLQueryItem(name: "id", value: "eq.\(id)")]
        let userToken = token ?? authManager.accessToken
        let (data, statusCode) = try await makeRequest("DELETE", path: "rest/v1/drivers", queryItems: queryItems, userToken: userToken)

        guard statusCode == 204 else {
            logErrorResponse(data, statusCode: statusCode, operation: "deleteDriver")
            throw NSError(domain: "DeleteDriver", code: statusCode)
        }
    }

    // MARK: - Saved Addresses

    func getSavedAddresses(userId: String, token: String? = nil) async throws -> [SavedAddressDTO] {
        // RLS scopes to family_id; no explicit filter needed
        let userToken = token ?? authManager.accessToken
        let (data, statusCode) = try await makeRequest("GET", path: "rest/v1/saved_addresses", userToken: userToken)

        guard statusCode == 200 else {
            logErrorResponse(data, statusCode: statusCode, operation: "getSavedAddresses")
            throw NSError(domain: "GetSavedAddresses", code: statusCode)
        }

        return try JSONDecoder().decode([SavedAddressDTO].self, from: data)
    }

    func createSavedAddress(
        userId: String,
        name: String,
        address: String,
        latitude: Double,
        longitude: Double,
        id: String? = nil,
        token: String? = nil
    ) async throws {
        struct CreateSavedAddressBody: Encodable {
            let user_id: String
            let family_id: String
            let name: String
            let address: String
            let latitude: Double
            let longitude: Double
            let id: String?
        }

        // Resolve family_id for shared visibility
        let familyId: String
        if let profile = try? await getProfile(userId: userId, token: token), let fid = profile.family_id {
            familyId = fid
        } else if let family = try? await getCurrentFamily(token: token) {
            familyId = family.id
        } else {
            throw NSError(domain: "CreateSavedAddress", code: -1, userInfo: [NSLocalizedDescriptionKey: "Missing family_id on profile"])
        }

        let body = CreateSavedAddressBody(
            user_id: userId,
            family_id: familyId,
            name: name,
            address: address,
            latitude: latitude,
            longitude: longitude,
            id: id
        )

        let userToken = token ?? authManager.accessToken
        let (data, statusCode) = try await makeRequest("POST", path: "rest/v1/saved_addresses", body: body, userToken: userToken)

        guard statusCode == 201 else {
            logErrorResponse(data, statusCode: statusCode, operation: "createSavedAddress")
            throw NSError(domain: "CreateSavedAddress", code: statusCode)
        }
    }

    func deleteSavedAddress(id: String, token: String? = nil) async throws {
        let queryItems = [URLQueryItem(name: "id", value: "eq.\(id)")]
        let userToken = token ?? authManager.accessToken
        let (data, statusCode) = try await makeRequest("DELETE", path: "rest/v1/saved_addresses", queryItems: queryItems, userToken: userToken)

        guard statusCode == 204 else {
            logErrorResponse(data, statusCode: statusCode, operation: "deleteSavedAddress")
            throw NSError(domain: "DeleteSavedAddress", code: statusCode)
        }
    }

    // MARK: - Calendar Event Metadata (app-only fields)

    func getCalendarEventMetadata(userId: String, token: String? = nil) async throws -> [CalendarEventMetadataDTO] {
        // RLS scopes to family_id; no explicit filter needed
        let userToken = token ?? authManager.accessToken
        let (data, statusCode) = try await makeRequest("GET", path: "rest/v1/calendar_event_metadata", userToken: userToken)

        guard statusCode == 200 else {
            logErrorResponse(data, statusCode: statusCode, operation: "getCalendarEventMetadata")
            throw NSError(domain: "GetCalendarEventMetadata", code: statusCode)
        }

        return try JSONDecoder().decode([CalendarEventMetadataDTO].self, from: data)
    }

    // MARK: - Calendar Event Metadata (app-only fields)

    func upsertCalendarEventMetadata(
        userId: String,
        eventIdentifier: String,
        driverFamilyMemberId: String?,
        notes: String? = nil,
        extra: [String: AnyCodable]? = nil,
        token: String? = nil
    ) async throws {
        struct MetadataBody: Encodable {
            let user_id: String
            let event_identifier: String
            let driver_family_member_id: String?
            let notes: String?
            let extra: [String: AnyCodable]?

            enum CodingKeys: String, CodingKey {
                case user_id, event_identifier, driver_family_member_id, notes, extra
            }

            // Encode nils explicitly so Supabase columns are cleared when a driver is removed
            func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                try container.encode(user_id, forKey: .user_id)
                try container.encode(event_identifier, forKey: .event_identifier)
                if let driver_family_member_id {
                    try container.encode(driver_family_member_id, forKey: .driver_family_member_id)
                } else {
                    try container.encodeNil(forKey: .driver_family_member_id)
                }
                if let notes {
                    try container.encode(notes, forKey: .notes)
                } else {
                    try container.encodeNil(forKey: .notes)
                }
                if let extra {
                    try container.encode(extra, forKey: .extra)
                } else {
                    try container.encodeNil(forKey: .extra)
                }
            }
        }

        let body = MetadataBody(
            user_id: userId,
            event_identifier: eventIdentifier,
            driver_family_member_id: driverFamilyMemberId,
            notes: notes,
            extra: extra
        )

        let userToken = token ?? authManager.accessToken

        // Primary attempt: upsert via POST with merge-duplicates
        let (postData, statusCode) = try await makeRequest(
            "POST",
            path: "rest/v1/calendar_event_metadata",
            body: body,
            userToken: userToken,
            extraHeaders: ["Prefer": "resolution=merge-duplicates"]
        )

        if statusCode == 201 || statusCode == 200 || statusCode == 204 {
            return
        }

        // If the record already exists, retry with PATCH to overwrite the existing row
        if statusCode == 409 {
            print("⚠️ UpsertCalendarEventMetadata hit 409, retrying with PATCH")
            let queryItems = [
                URLQueryItem(name: "user_id", value: "eq.\(userId)"),
                URLQueryItem(name: "event_identifier", value: "eq.\(eventIdentifier)")
            ]

            let (_, patchStatus) = try await makeRequest(
                "PATCH",
                path: "rest/v1/calendar_event_metadata",
                queryItems: queryItems,
                body: body,
                userToken: userToken,
                extraHeaders: ["Prefer": "return=minimal"]
            )

            guard patchStatus == 200 || patchStatus == 204 else {
                logErrorResponse(postData, statusCode: statusCode, operation: "upsertCalendarEventMetadata_POST")
                print("❌ Patch calendar_event_metadata failed with status \(patchStatus)")
                throw NSError(domain: "UpsertCalendarEventMetadata", code: patchStatus)
            }

            return
        }

        logErrorResponse(postData, statusCode: statusCode, operation: "upsertCalendarEventMetadata_POST")

        // If we're clearing driver info (all metadata is nil/empty), try deleting the row as a fallback
        let isClearingDriver = driverFamilyMemberId == nil && (extra == nil || extra?.isEmpty == true) && (notes == nil || notes?.isEmpty == true)
        if isClearingDriver {
            let deleteQuery = [
                URLQueryItem(name: "user_id", value: "eq.\(userId)"),
                URLQueryItem(name: "event_identifier", value: "eq.\(eventIdentifier)")
            ]
            let (deleteData, deleteStatus) = try await makeRequest(
                "DELETE",
                path: "rest/v1/calendar_event_metadata",
                queryItems: deleteQuery,
                userToken: userToken
            )

            if deleteStatus == 200 || deleteStatus == 204 {
                print("✅ Deleted calendar_event_metadata row while clearing driver")
                return
            } else {
                logErrorResponse(deleteData, statusCode: deleteStatus, operation: "upsertCalendarEventMetadata_DELETE")
            }
        }

        print("❌ UpsertCalendarEventMetadata failed with status \(statusCode)")
        throw NSError(domain: "UpsertCalendarEventMetadata", code: statusCode)
    }

    // MARK: - Soft Delete Event Metadata

    func syncSoftDeletedEvent(
        userId: String,
        eventIdentifier: String,
        isAttending: Bool,
        deletionType: String? = nil,
        deletionReason: String? = nil,
        token: String? = nil
    ) async throws {
        struct SoftDeleteBody: Encodable {
            let user_id: String
            let event_identifier: String
            let is_attending: Bool
            let deletion_type: String?
            let deleted_at: String?
            let deletion_reason: String?

            enum CodingKeys: String, CodingKey {
                case user_id, event_identifier, is_attending, deletion_type, deleted_at, deletion_reason
            }

            func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                try container.encode(user_id, forKey: .user_id)
                try container.encode(event_identifier, forKey: .event_identifier)
                try container.encode(is_attending, forKey: .is_attending)

                if let deletion_type {
                    try container.encode(deletion_type, forKey: .deletion_type)
                } else {
                    try container.encodeNil(forKey: .deletion_type)
                }

                if let deleted_at {
                    try container.encode(deleted_at, forKey: .deleted_at)
                } else {
                    try container.encodeNil(forKey: .deleted_at)
                }

                if let deletion_reason {
                    try container.encode(deletion_reason, forKey: .deletion_reason)
                } else {
                    try container.encodeNil(forKey: .deletion_reason)
                }
            }
        }

        let deletedAtValue = !isAttending ? ISO8601DateFormatter().string(from: Date()) : nil
        let body = SoftDeleteBody(
            user_id: userId,
            event_identifier: eventIdentifier,
            is_attending: isAttending,
            deletion_type: deletionType,
            deleted_at: deletedAtValue,
            deletion_reason: deletionReason
        )

        let userToken = token ?? authManager.accessToken

        // Try upsert via POST with merge-duplicates
        let (postData, statusCode) = try await makeRequest(
            "POST",
            path: "rest/v1/family_events",
            body: body,
            userToken: userToken,
            extraHeaders: ["Prefer": "resolution=merge-duplicates"]
        )

        if statusCode == 201 || statusCode == 200 || statusCode == 204 {
            print("✅ Synced soft delete status for event \(eventIdentifier)")
            return
        }

        // If conflict, retry with PATCH
        if statusCode == 409 {
            print("⚠️ syncSoftDeletedEvent hit 409, retrying with PATCH")
            let queryItems = [
                URLQueryItem(name: "user_id", value: "eq.\(userId)"),
                URLQueryItem(name: "event_identifier", value: "eq.\(eventIdentifier)")
            ]

            let (_, patchStatus) = try await makeRequest(
                "PATCH",
                path: "rest/v1/family_events",
                queryItems: queryItems,
                body: body,
                userToken: userToken,
                extraHeaders: ["Prefer": "return=minimal"]
            )

            guard patchStatus == 200 || patchStatus == 204 else {
                logErrorResponse(postData, statusCode: statusCode, operation: "syncSoftDeletedEvent_PATCH")
                print("❌ Patch family_events failed with status \(patchStatus)")
                throw NSError(domain: "SyncSoftDeletedEvent", code: patchStatus)
            }

            return
        }

        logErrorResponse(postData, statusCode: statusCode, operation: "syncSoftDeletedEvent_POST")
        print("❌ syncSoftDeletedEvent failed with status \(statusCode)")
        throw NSError(domain: "SyncSoftDeletedEvent", code: statusCode)
    }

    func restoreSoftDeletedEvent(
        userId: String,
        eventIdentifier: String,
        token: String? = nil
    ) async throws {
        struct RestoreBody: Encodable {
            let user_id: String
            let event_identifier: String
            let is_attending: Bool
            let deletion_type: String?
            let deleted_at: String?
            let deletion_reason: String?

            enum CodingKeys: String, CodingKey {
                case user_id, event_identifier, is_attending, deletion_type, deleted_at, deletion_reason
            }

            func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                try container.encode(user_id, forKey: .user_id)
                try container.encode(event_identifier, forKey: .event_identifier)
                try container.encode(true, forKey: .is_attending)  // Mark as attending again
                try container.encodeNil(forKey: .deletion_type)
                try container.encodeNil(forKey: .deleted_at)
                try container.encodeNil(forKey: .deletion_reason)
            }
        }

        let body = RestoreBody(
            user_id: userId,
            event_identifier: eventIdentifier,
            is_attending: true,
            deletion_type: nil,
            deleted_at: nil,
            deletion_reason: nil
        )

        let userToken = token ?? authManager.accessToken

        let queryItems = [
            URLQueryItem(name: "user_id", value: "eq.\(userId)"),
            URLQueryItem(name: "event_identifier", value: "eq.\(eventIdentifier)")
        ]

        let (_, status) = try await makeRequest(
            "PATCH",
            path: "rest/v1/family_events",
            queryItems: queryItems,
            body: body,
            userToken: userToken,
            extraHeaders: ["Prefer": "return=minimal"]
        )

        guard status == 200 || status == 204 else {
            print("❌ restoreSoftDeletedEvent failed with status \(status)")
            throw NSError(domain: "RestoreSoftDeletedEvent", code: status)
        }

        print("✅ Restored soft deleted event \(eventIdentifier)")
    }

    // MARK: - Checklists

    /// Fetch checklists for specific event identifiers
    func fetchChecklists(for eventIdentifiers: [String], token: String? = nil) async throws -> [ChecklistDTO] {
        guard !eventIdentifiers.isEmpty else { return [] }

        // For PostgREST in() operator with text fields, wrap each string in double quotes
        let quotedIds = eventIdentifiers.map { "\"\($0)\"" }.joined(separator: ",")
        // Filter out soft-deleted checklists (deleted_at IS NULL)
        let queryItems = [
            URLQueryItem(name: "event_identifier", value: "in.(\(quotedIds))"),
            URLQueryItem(name: "deleted_at", value: "is.null")
        ]
        let userToken = token ?? authManager.accessToken

        let (data, statusCode) = try await makeRequest(
            "GET",
            path: "rest/v1/event_checklists",
            queryItems: queryItems,
            userToken: userToken
        )

        guard statusCode == 200 else {
            logErrorResponse(data, statusCode: statusCode, operation: "fetchChecklists")
            throw NSError(domain: "FetchChecklists", code: statusCode)
        }

        return try JSONDecoder().decode([ChecklistDTO].self, from: data)
    }

    /// Fetch checklist items for specific checklists
    func fetchChecklistItems(for checklistIds: [String], token: String? = nil) async throws -> [ChecklistItemDTO] {
        guard !checklistIds.isEmpty else { return [] }

        let ids = checklistIds.joined(separator: ",")
        // Filter out soft-deleted items (deleted_at IS NULL)
        let queryItems = [
            URLQueryItem(name: "checklist_id", value: "in.(\(ids))"),
            URLQueryItem(name: "deleted_at", value: "is.null")
        ]
        let userToken = token ?? authManager.accessToken

        let (data, statusCode) = try await makeRequest(
            "GET",
            path: "rest/v1/checklist_items",
            queryItems: queryItems,
            userToken: userToken
        )

        guard statusCode == 200 else {
            logErrorResponse(data, statusCode: statusCode, operation: "fetchChecklistItems")
            throw NSError(domain: "FetchChecklistItems", code: statusCode)
        }

        return try JSONDecoder().decode([ChecklistItemDTO].self, from: data)
    }

    /// Fetch a single checklist by ID
    func fetchChecklist(id: String, token: String? = nil) async throws -> ChecklistDTO? {
        // Filter out soft-deleted checklists (deleted_at IS NULL)
        let queryItems = [
            URLQueryItem(name: "id", value: "eq.\(id)"),
            URLQueryItem(name: "deleted_at", value: "is.null")
        ]
        let userToken = token ?? authManager.accessToken

        let (data, statusCode) = try await makeRequest(
            "GET",
            path: "rest/v1/event_checklists",
            queryItems: queryItems,
            userToken: userToken
        )

        guard statusCode == 200 else {
            logErrorResponse(data, statusCode: statusCode, operation: "fetchChecklist")
            throw NSError(domain: "FetchChecklist", code: statusCode)
        }

        let checklists = try JSONDecoder().decode([ChecklistDTO].self, from: data)
        return checklists.first
    }

    /// Fetch all checklists (including standalone ones)
    func fetchAllChecklists(token: String? = nil) async throws -> [ChecklistDTO] {
        let userToken = token ?? authManager.accessToken

        // Filter out soft-deleted checklists (deleted_at IS NULL)
        let queryItems = [URLQueryItem(name: "deleted_at", value: "is.null")]

        let (data, statusCode) = try await makeRequest(
            "GET",
            path: "rest/v1/event_checklists",
            queryItems: queryItems,
            userToken: userToken
        )

        guard statusCode == 200 else {
            logErrorResponse(data, statusCode: statusCode, operation: "fetchAllChecklists")
            throw NSError(domain: "FetchAllChecklists", code: statusCode)
        }

        return try JSONDecoder().decode([ChecklistDTO].self, from: data)
    }

    /// Create or update a checklist
    func upsertChecklist(_ dto: ChecklistDTO, token: String? = nil) async throws -> ChecklistDTO {
        let userToken = token ?? authManager.accessToken

        struct UpsertBody: Encodable {
            let id: String
            let event_identifier: String
            let event_group_id: String?
            let event_title: String?
            let deleted_at: String?
            let deletion_reason: String?
        }

        let body = UpsertBody(
            id: dto.id,
            event_identifier: dto.event_identifier,
            event_group_id: dto.event_group_id,
            event_title: dto.event_title,
            deleted_at: dto.deleted_at,
            deletion_reason: dto.deletion_reason
        )

        // POST with merge-duplicates for automatic conflict handling
        // This tells Supabase to update if record exists, insert if not
        let (data, statusCode) = try await makeRequest(
            "POST",
            path: "rest/v1/event_checklists",
            body: body,
            userToken: userToken,
            extraHeaders: [
                "Prefer": "return=representation,resolution=merge-duplicates"
            ]
        )

        // If we got 409, fall back to PATCH update
        if statusCode == 409 {
            print("⚠️ POST got 409, attempting PATCH update")
            let (patchData, patchStatusCode) = try await makeRequest(
                "PATCH",
                path: "rest/v1/event_checklists?id=eq.\(dto.id)",
                body: body,
                userToken: userToken,
                extraHeaders: ["Prefer": "return=representation"]
            )

            guard patchStatusCode == 200 else {
                logErrorResponse(patchData, statusCode: patchStatusCode, operation: "upsertChecklist (PATCH)")
                throw NSError(domain: "UpsertChecklist", code: patchStatusCode)
            }

            let checklists = try JSONDecoder().decode([ChecklistDTO].self, from: patchData)
            guard let checklist = checklists.first else {
                throw NSError(domain: "UpsertChecklist", code: -1, userInfo: [NSLocalizedDescriptionKey: "No record returned from PATCH"])
            }
            print("✅ Checklist updated via PATCH: \(dto.id)")
            return checklist
        }

        guard statusCode == 200 || statusCode == 201 else {
            logErrorResponse(data, statusCode: statusCode, operation: "upsertChecklist")
            throw NSError(domain: "UpsertChecklist", code: statusCode)
        }

        let checklists = try JSONDecoder().decode([ChecklistDTO].self, from: data)
        guard let checklist = checklists.first else {
            throw NSError(domain: "UpsertChecklist", code: -1, userInfo: [NSLocalizedDescriptionKey: "Checklist not returned after upsert"])
        }
        print("✅ Checklist synced: \(dto.id)")
        return checklist
    }

    /// Create or update a checklist item
    func upsertChecklistItem(_ dto: ChecklistItemDTO, token: String? = nil) async throws -> ChecklistItemDTO {
        let userToken = token ?? authManager.accessToken

        struct UpsertBody: Encodable {
            let id: String
            let checklist_id: String
            let title: String
            let due_date: String?
            let completed: Bool
            let completed_at: String?
            let completed_by: String?
            let sort_order: Int
            let deleted_at: String?
            let notification_id: String?
        }

        let body = UpsertBody(
            id: dto.id,
            checklist_id: dto.checklist_id,
            title: dto.title,
            due_date: dto.due_date,
            completed: dto.completed,
            completed_at: dto.completed_at,
            completed_by: dto.completed_by,
            sort_order: dto.sort_order,
            deleted_at: dto.deleted_at,
            notification_id: dto.notification_id
        )

        // POST with merge-duplicates for automatic conflict handling
        let (data, statusCode) = try await makeRequest(
            "POST",
            path: "rest/v1/checklist_items",
            body: body,
            userToken: userToken,
            extraHeaders: [
                "Prefer": "return=representation,resolution=merge-duplicates"
            ]
        )

        // If we got 409, fall back to PATCH update
        if statusCode == 409 {
            print("⚠️ POST got 409, attempting PATCH update for item \(dto.id)")
            let (patchData, patchStatusCode) = try await makeRequest(
                "PATCH",
                path: "rest/v1/checklist_items?id=eq.\(dto.id)",
                body: body,
                userToken: userToken,
                extraHeaders: ["Prefer": "return=representation"]
            )

            guard patchStatusCode == 200 else {
                logErrorResponse(patchData, statusCode: patchStatusCode, operation: "upsertChecklistItem (PATCH)")
                throw NSError(domain: "UpsertChecklistItem", code: patchStatusCode)
            }

            let items = try JSONDecoder().decode([ChecklistItemDTO].self, from: patchData)
            guard let item = items.first else {
                throw NSError(domain: "UpsertChecklistItem", code: -1, userInfo: [NSLocalizedDescriptionKey: "No item returned from PATCH"])
            }
            print("✅ Item updated via PATCH: \(dto.id)")
            return item
        }

        guard statusCode == 200 || statusCode == 201 else {
            logErrorResponse(data, statusCode: statusCode, operation: "upsertChecklistItem")
            throw NSError(domain: "UpsertChecklistItem", code: statusCode)
        }

        let items = try JSONDecoder().decode([ChecklistItemDTO].self, from: data)
        guard let item = items.first else {
            throw NSError(domain: "UpsertChecklistItem", code: -1, userInfo: [NSLocalizedDescriptionKey: "Checklist item not returned after upsert"])
        }
        print("✅ Item synced: \(dto.id)")
        return item
    }

    /// Delete (soft delete) a checklist
    func deleteChecklist(id: String, reason: String? = nil, token: String? = nil) async throws {
        let userToken = token ?? authManager.accessToken

        struct DeleteBody: Encodable {
            let deleted_at: String
            let deletion_reason: String?
        }

        let now = ISO8601DateFormatter().string(from: Date())
        let body = DeleteBody(deleted_at: now, deletion_reason: reason)

        let queryItems = [URLQueryItem(name: "id", value: "eq.\(id)")]
        let (data, statusCode) = try await makeRequest(
            "PATCH",
            path: "rest/v1/event_checklists",
            queryItems: queryItems,
            body: body,
            userToken: userToken,
            extraHeaders: ["Prefer": "return=minimal"]
        )

        guard statusCode == 200 || statusCode == 204 else {
            logErrorResponse(data, statusCode: statusCode, operation: "deleteChecklist")
            throw NSError(domain: "DeleteChecklist", code: statusCode)
        }
    }

    /// Delete (soft delete) a checklist item
    func deleteChecklistItem(id: String, token: String? = nil) async throws {
        let userToken = token ?? authManager.accessToken

        struct DeleteBody: Encodable {
            let deleted_at: String
        }

        let now = ISO8601DateFormatter().string(from: Date())
        let body = DeleteBody(deleted_at: now)

        let queryItems = [URLQueryItem(name: "id", value: "eq.\(id)")]
        let (data, statusCode) = try await makeRequest(
            "PATCH",
            path: "rest/v1/checklist_items",
            queryItems: queryItems,
            body: body,
            userToken: userToken,
            extraHeaders: ["Prefer": "return=minimal"]
        )

        guard statusCode == 200 || statusCode == 204 else {
            logErrorResponse(data, statusCode: statusCode, operation: "deleteChecklistItem")
            throw NSError(domain: "DeleteChecklistItem", code: statusCode)
        }
    }
}

// MARK: - Data Transfer Objects

struct FamilyMemberDTO: Codable {
    let id: String
    let user_id: String
    let family_id: String?
    let linked_user_id: String?
    let name: String
    let color_hex: String
    let is_driver: Bool?
    let created_at: String?

    enum CodingKeys: String, CodingKey {
        case id, user_id, family_id, linked_user_id, name, color_hex, is_driver, created_at
    }
}

struct FamilyMemberCalendarDTO: Codable {
    let id: String
    let family_member_id: String
    let calendar_name: String
    let calendar_color_hex: String
    let is_auto_linked: Bool
    let created_at: String?

    enum CodingKeys: String, CodingKey {
        case id, family_member_id, calendar_name, calendar_color_hex, is_auto_linked, created_at
    }
}

struct SharedCalendarDTO: Codable {
    let id: String
    let user_id: String
    let calendar_name: String
    let calendar_color_hex: String
    let created_at: String?

    enum CodingKeys: String, CodingKey {
        case id, user_id, calendar_name, calendar_color_hex, created_at
    }
}

struct PersonalCalendarDTO: Codable {
    let id: String
    let user_id: String
    let calendar_name: String
    let calendar_color_hex: String
    let show_in_next: Bool?
    let show_in_spotlight: Bool?
    let show_in_upcoming: Bool?
    let show_in_month: Bool?
    let show_in_day: Bool?
    let created_at: String?

    enum CodingKeys: String, CodingKey {
        case id, user_id, calendar_name, calendar_color_hex, show_in_next, show_in_spotlight, show_in_upcoming, show_in_month, show_in_day, created_at
    }
}

struct AppSettingsDTO: Codable {
    let id: String
    let user_id: String
    let settings: [String: AnyCodable]
    let created_at: String?
    let updated_at: String?

    enum CodingKeys: String, CodingKey {
        case id, user_id, settings, created_at, updated_at
    }
}

struct AppSettingsCreateRequest: Codable {
    let user_id: String
    let settings: [String: AnyCodable]

    enum CodingKeys: String, CodingKey {
        case user_id, settings
    }
}

struct AppSettingsUpdateRequest: Codable {
    let settings: [String: AnyCodable]

    enum CodingKeys: String, CodingKey {
        case settings
    }
}

struct CalendarEventMetadataDTO: Codable {
    let id: String
    let user_id: String
    let event_identifier: String
    let driver_family_member_id: String?
    let notes: String?
    let extra: [String: AnyCodable]?
    let created_at: String?
    let updated_at: String?

    enum CodingKeys: String, CodingKey {
        case id, user_id, event_identifier, driver_family_member_id, notes, extra, created_at, updated_at
    }
}

// MARK: - AnyCodable Helper for Dynamic Settings

struct DriverDTO: Codable {
    let id: String
    let user_id: String?
    let name: String?
    let phone: String?
    let email: String?
    let notes: String?
    let travel_time_minutes: Int?
    let family_member_id: String?
    let travel_event_identifier: String?
    let created_at: String?
    let updated_at: String?

    enum CodingKeys: String, CodingKey {
        case id
        case user_id
        case name
        case phone
        case email
        case notes
        case travel_time_minutes
        case family_member_id
        case travel_event_identifier
        case created_at
        case updated_at
    }
}

struct SavedAddressDTO: Codable {
    let id: String
    let user_id: String?
    let name: String?
    let address: String?
    let latitude: Double?
    let longitude: Double?
    let created_at: String?
    let updated_at: String?

    enum CodingKeys: String, CodingKey {
        case id
        case user_id
        case name
        case address
        case latitude
        case longitude
        case created_at
        case updated_at
    }
}

enum AnyCodable: Codable {
    case null
    case bool(Bool)
    case int(Int)
    case double(Double)
    case string(String)
    case array([AnyCodable])
    case dict([String: AnyCodable])

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self = .null
        } else if let bool = try? container.decode(Bool.self) {
            self = .bool(bool)
        } else if let int = try? container.decode(Int.self) {
            self = .int(int)
        } else if let double = try? container.decode(Double.self) {
            self = .double(double)
        } else if let string = try? container.decode(String.self) {
            self = .string(string)
        } else if let array = try? container.decode([AnyCodable].self) {
            self = .array(array)
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            self = .dict(dict)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode AnyCodable")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch self {
        case .null:
            try container.encodeNil()
        case .bool(let bool):
            try container.encode(bool)
        case .int(let int):
            try container.encode(int)
        case .double(let double):
            try container.encode(double)
        case .string(let string):
            try container.encode(string)
        case .array(let array):
            try container.encode(array)
        case .dict(let dict):
            try container.encode(dict)
        }
    }
}
