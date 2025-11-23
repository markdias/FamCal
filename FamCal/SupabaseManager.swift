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

    init(authManager: SupabaseAuthManager = SupabaseAuthManager.shared) {
        self.supabaseURL = URL(string: SupabaseConfig.supabaseURL)!
        self.anonKey = SupabaseConfig.supabaseAnonKey
        self.authManager = authManager
    }

    // MARK: - Helper Methods

    private func makeRequest(_ method: String, path: String, body: Encodable? = nil, userToken: String? = nil) async throws -> (data: Data, statusCode: Int) {
        let url = supabaseURL.appendingPathComponent(path)
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")

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

        return (data, httpResponse.statusCode)
    }

    private func logErrorResponse(_ data: Data, statusCode: Int, operation: String) {
        if let errorString = String(data: data, encoding: .utf8) {
            print("❌ [\(operation)] HTTP \(statusCode): \(errorString)")
        }
    }

    // MARK: - Family Members

    func createFamilyMember(userId: String, name: String, colorHex: String, token: String? = nil) async throws {
        let body: [String: String] = [
            "user_id": userId,
            "name": name,
            "color_hex": colorHex
        ]

        let userToken = token ?? authManager.accessToken
        let (data, statusCode) = try await makeRequest("POST", path: "rest/v1/family_members", body: body, userToken: userToken)

        guard statusCode == 201 else {
            logErrorResponse(data, statusCode: statusCode, operation: "createFamilyMember")

            // If we got 409 (conflict), it's likely a duplicate name constraint
            if statusCode == 409 {
                if let errorResponse = String(data: data, encoding: .utf8) {
                    print("ℹ️ 409 Conflict details: \(errorResponse)")
                    if errorResponse.contains("unique") || errorResponse.contains("family_member") {
                        print("⚠️ Duplicate family member name. Names must be unique per user.")
                        print("ℹ️ Family member '\(name)' already exists for this user.")
                    }
                }
            }

            throw NSError(domain: "CreateFamilyMember", code: statusCode)
        }
    }

    func getFamilyMembers(userId: String, token: String? = nil) async throws -> [FamilyMemberDTO] {
        let path = "rest/v1/family_members?user_id=eq.\(userId)"
        let userToken = token ?? authManager.accessToken
        let (data, statusCode) = try await makeRequest("GET", path: path, userToken: userToken)

        guard statusCode == 200 else {
            logErrorResponse(data, statusCode: statusCode, operation: "getFamilyMembers")
            throw NSError(domain: "GetFamilyMembers", code: statusCode)
        }

        return try JSONDecoder().decode([FamilyMemberDTO].self, from: data)
    }

    func updateFamilyMember(id: String, name: String, colorHex: String, token: String? = nil) async throws {
        let body: [String: String] = [
            "name": name,
            "color_hex": colorHex
        ]

        let userToken = token ?? authManager.accessToken
        let (_, statusCode) = try await makeRequest("PATCH", path: "rest/v1/family_members?id=eq.\(id)", body: body, userToken: userToken)

        guard statusCode == 200 else {
            throw NSError(domain: "UpdateFamilyMember", code: statusCode)
        }
    }

    func deleteFamilyMember(id: String, token: String? = nil) async throws {
        let userToken = token ?? authManager.accessToken
        let (_, statusCode) = try await makeRequest("DELETE", path: "rest/v1/family_members?id=eq.\(id)", userToken: userToken)

        guard statusCode == 204 else {
            throw NSError(domain: "DeleteFamilyMember", code: statusCode)
        }
    }

    // MARK: - Family Member Calendars

    func addFamilyMemberCalendar(memberId: String, calendarId: String, calendarName: String, calendarColorHex: String, isAutoLinked: Bool, token: String? = nil) async throws {
        struct CalendarBody: Encodable {
            let family_member_id: String
            let calendar_id: String
            let calendar_name: String
            let calendar_color_hex: String
            let is_auto_linked: Bool
        }

        let body = CalendarBody(
            family_member_id: memberId,
            calendar_id: calendarId,
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
        let path = "rest/v1/family_member_calendars?family_member_id=eq.\(memberId)"
        let userToken = token ?? authManager.accessToken
        let (data, statusCode) = try await makeRequest("GET", path: path, userToken: userToken)

        guard statusCode == 200 else {
            throw NSError(domain: "GetFamilyMemberCalendars", code: statusCode)
        }

        return try JSONDecoder().decode([FamilyMemberCalendarDTO].self, from: data)
    }

    func deleteFamilyMemberCalendar(id: String, token: String? = nil) async throws {
        let userToken = token ?? authManager.accessToken
        let (_, statusCode) = try await makeRequest("DELETE", path: "rest/v1/family_member_calendars?id=eq.\(id)", userToken: userToken)

        guard statusCode == 204 else {
            throw NSError(domain: "DeleteFamilyMemberCalendar", code: statusCode)
        }
    }

    // MARK: - Shared Calendars

    func addSharedCalendar(userId: String, calendarId: String, calendarName: String, calendarColorHex: String, token: String? = nil) async throws {
        let body: [String: String] = [
            "user_id": userId,
            "calendar_id": calendarId,
            "calendar_name": calendarName,
            "calendar_color_hex": calendarColorHex
        ]

        let userToken = token ?? authManager.accessToken
        let (_, statusCode) = try await makeRequest("POST", path: "rest/v1/shared_calendars", body: body, userToken: userToken)

        guard statusCode == 201 else {
            throw NSError(domain: "AddSharedCalendar", code: statusCode)
        }
    }

    func getSharedCalendars(userId: String, token: String? = nil) async throws -> [SharedCalendarDTO] {
        let path = "rest/v1/shared_calendars?user_id=eq.\(userId)"
        let userToken = token ?? authManager.accessToken
        let (data, statusCode) = try await makeRequest("GET", path: path, userToken: userToken)

        guard statusCode == 200 else {
            throw NSError(domain: "GetSharedCalendars", code: statusCode)
        }

        return try JSONDecoder().decode([SharedCalendarDTO].self, from: data)
    }

    func deleteSharedCalendar(id: String, token: String? = nil) async throws {
        let userToken = token ?? authManager.accessToken
        let (_, statusCode) = try await makeRequest("DELETE", path: "rest/v1/shared_calendars?id=eq.\(id)", userToken: userToken)

        guard statusCode == 204 else {
            throw NSError(domain: "DeleteSharedCalendar", code: statusCode)
        }
    }
}

// MARK: - Data Transfer Objects

struct FamilyMemberDTO: Codable {
    let id: String
    let user_id: String
    let name: String
    let color_hex: String
    let created_at: String?

    enum CodingKeys: String, CodingKey {
        case id, user_id, name, color_hex, created_at
    }
}

struct FamilyMemberCalendarDTO: Codable {
    let id: String
    let family_member_id: String
    let calendar_id: String
    let calendar_name: String
    let calendar_color_hex: String
    let is_auto_linked: Bool
    let created_at: String?

    enum CodingKeys: String, CodingKey {
        case id, family_member_id, calendar_id, calendar_name, calendar_color_hex, is_auto_linked, created_at
    }
}

struct SharedCalendarDTO: Codable {
    let id: String
    let user_id: String
    let calendar_id: String
    let calendar_name: String
    let calendar_color_hex: String
    let created_at: String?

    enum CodingKeys: String, CodingKey {
        case id, user_id, calendar_id, calendar_name, calendar_color_hex, created_at
    }
}
