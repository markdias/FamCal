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
        extraHeaders: [String: String] = [:]
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
        let queryItems = [URLQueryItem(name: "user_id", value: "eq.\(userId)")]
        let userToken = token ?? authManager.accessToken
        let (data, statusCode) = try await makeRequest("GET", path: "rest/v1/family_members", queryItems: queryItems, userToken: userToken)

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

        let queryItems = [URLQueryItem(name: "id", value: "eq.\(id)")]
        let userToken = token ?? authManager.accessToken
        let (_, statusCode) = try await makeRequest("PATCH", path: "rest/v1/family_members", queryItems: queryItems, body: body, userToken: userToken)

        guard statusCode == 200 else {
            throw NSError(domain: "UpdateFamilyMember", code: statusCode)
        }
    }

    func deleteFamilyMember(id: String, token: String? = nil) async throws {
        let queryItems = [URLQueryItem(name: "id", value: "eq.\(id)")]
        let userToken = token ?? authManager.accessToken
        let (_, statusCode) = try await makeRequest("DELETE", path: "rest/v1/family_members", queryItems: queryItems, userToken: userToken)

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

    func addSharedCalendar(userId: String, calendarId: String, calendarName: String, calendarColorHex: String, token: String? = nil) async throws -> SharedCalendarDTO {
        let body: [String: String] = [
            "user_id": userId,
            "calendar_id": calendarId,
            "calendar_name": calendarName,
            "calendar_color_hex": calendarColorHex
        ]

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
            guard let newCalendar = sharedCals.first(where: { $0.calendar_id == calendarId }) else {
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
        let queryItems = [URLQueryItem(name: "user_id", value: "eq.\(userId)")]
        let userToken = token ?? authManager.accessToken
        let (data, statusCode) = try await makeRequest("GET", path: "rest/v1/shared_calendars", queryItems: queryItems, userToken: userToken)

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
        }

        let body = CreateDriverBody(
            user_id: userId,
            name: name,
            phone: phone,
            email: email,
            notes: notes,
            travel_time_minutes: travelTimeMinutes,
            family_member_id: familyMemberId
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
            let email: String?
            let notes: String?
            let travel_time_minutes: Int
            let family_member_id: String?
        }

        let body = UpdateDriverBody(
            name: name,
            phone: phone,
            email: email,
            notes: notes,
            travel_time_minutes: travelTimeMinutes,
            family_member_id: familyMemberId
        )

        let queryItems = [URLQueryItem(name: "id", value: "eq.\(id)")]
        let userToken = token ?? authManager.accessToken
        let (data, statusCode) = try await makeRequest("PATCH", path: "rest/v1/drivers", queryItems: queryItems, body: body, userToken: userToken)

        guard statusCode == 200 else {
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
        let queryItems = [URLQueryItem(name: "user_id", value: "eq.\(userId)")]
        let userToken = token ?? authManager.accessToken
        let (data, statusCode) = try await makeRequest("GET", path: "rest/v1/saved_addresses", queryItems: queryItems, userToken: userToken)

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
        token: String? = nil
    ) async throws {
        struct CreateSavedAddressBody: Encodable {
            let user_id: String
            let name: String
            let address: String
            let latitude: Double
            let longitude: Double
        }

        let body = CreateSavedAddressBody(
            user_id: userId,
            name: name,
            address: address,
            latitude: latitude,
            longitude: longitude
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
        let queryItems = [URLQueryItem(name: "user_id", value: "eq.\(userId)")]
        let userToken = token ?? authManager.accessToken
        let (data, statusCode) = try await makeRequest("GET", path: "rest/v1/calendar_event_metadata", queryItems: queryItems, userToken: userToken)

        guard statusCode == 200 else {
            logErrorResponse(data, statusCode: statusCode, operation: "getCalendarEventMetadata")
            throw NSError(domain: "GetCalendarEventMetadata", code: statusCode)
        }

        return try JSONDecoder().decode([CalendarEventMetadataDTO].self, from: data)
    }

    // MARK: - Calendar Event Metadata (app-only fields)

    func upsertCalendarEventMetadata(
        userId: String,
        calendarId: String,
        eventIdentifier: String,
        driverFamilyMemberId: String?,
        notes: String? = nil,
        extra: [String: AnyCodable]? = nil,
        token: String? = nil
    ) async throws {
        struct MetadataBody: Encodable {
            let user_id: String
            let calendar_id: String
            let event_identifier: String
            let driver_family_member_id: String?
            let notes: String?
            let extra: [String: AnyCodable]?

            enum CodingKeys: String, CodingKey {
                case user_id, calendar_id, event_identifier, driver_family_member_id, notes, extra
            }

            // Encode nils explicitly so Supabase columns are cleared when a driver is removed
            func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                try container.encode(user_id, forKey: .user_id)
                try container.encode(calendar_id, forKey: .calendar_id)
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
            calendar_id: calendarId,
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
                URLQueryItem(name: "calendar_id", value: "eq.\(calendarId)"),
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
                URLQueryItem(name: "calendar_id", value: "eq.\(calendarId)"),
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
    let calendar_id: String
    let event_identifier: String
    let driver_family_member_id: String?
    let notes: String?
    let extra: [String: AnyCodable]?
    let created_at: String?
    let updated_at: String?

    enum CodingKeys: String, CodingKey {
        case id, user_id, calendar_id, event_identifier, driver_family_member_id, notes, extra, created_at, updated_at
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
