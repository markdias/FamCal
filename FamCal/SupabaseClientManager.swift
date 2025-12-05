//
//  SupabaseClientManager.swift
//  FamCal
//
//  Created: 2025-12-05
//  Purpose: Provides centralized Supabase client instance for SDK-based queries
//

import Foundation
import Auth
import PostgREST
import Realtime
import Storage

/// Manager providing a configured SupabaseClient for use with Supabase Swift SDK
class SupabaseClientManager {
    static let shared = SupabaseClientManager()

    let client: SupabaseClient

    private init() {
        // Initialize SupabaseClient with config values
        self.client = SupabaseClient(
            supabaseURL: URL(string: SupabaseConfig.supabaseURL)!,
            supabaseKey: SupabaseConfig.supabaseAnonKey
        )
    }
}

/// SupabaseClient wrapper providing fluent query interface
/// This mimics the official Supabase Swift SDK client structure
class SupabaseClient {
    private let supabaseURL: URL
    private let supabaseKey: String
    private let session: URLSession

    init(supabaseURL: URL, supabaseKey: String) {
        self.supabaseURL = supabaseURL
        self.supabaseKey = supabaseKey
        self.session = URLSession.shared
    }

    /// Returns a query builder for the specified table
    func from(_ table: String) -> PostgrestQueryBuilder {
        return PostgrestQueryBuilder(
            table: table,
            supabaseURL: supabaseURL,
            supabaseKey: supabaseKey,
            session: session
        )
    }
}

/// Query builder for constructing and executing PostgREST queries
class PostgrestQueryBuilder {
    private let table: String
    private let supabaseURL: URL
    private let supabaseKey: String
    private let session: URLSession

    private var selectQuery: String?
    private var filters: [(key: String, operation: String, value: String)] = []

    init(table: String, supabaseURL: URL, supabaseKey: String, session: URLSession) {
        self.table = table
        self.supabaseURL = supabaseURL
        self.supabaseKey = supabaseKey
        self.session = session
    }

    /// Specify which columns to select
    func select(_ columns: String = "*") -> PostgrestQueryBuilder {
        self.selectQuery = columns
        return self
    }

    /// Add greater-than-or-equal filter
    func gte(_ column: String, value: String) -> PostgrestQueryBuilder {
        filters.append((column, "gte", value))
        return self
    }

    /// Add IN filter for matching multiple values
    func `in`(_ column: String, values: [String]) -> PostgrestQueryBuilder {
        let valuesList = values.map { "\"\($0)\"" }.joined(separator: ",")
        filters.append((column, "in", "(\(valuesList))"))
        return self
    }

    /// Execute the query and return the response
    func execute() async throws -> PostgrestResponse {
        // Build URL with query parameters
        var components = URLComponents(url: supabaseURL.appendingPathComponent("rest/v1/\(table)"), resolvingAgainstBaseURL: false)!

        var queryItems: [URLQueryItem] = []

        // Add select parameter
        if let selectQuery = selectQuery {
            queryItems.append(URLQueryItem(name: "select", value: selectQuery))
        }

        // Add filters
        for filter in filters {
            queryItems.append(URLQueryItem(name: filter.key, value: "\(filter.operation).\(filter.value)"))
        }

        components.queryItems = queryItems.isEmpty ? nil : queryItems

        guard let url = components.url else {
            throw SupabaseError.invalidURL
        }

        // Create request
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(supabaseKey, forHTTPHeaderField: "apikey")

        // Get auth token if available
        if let token = SupabaseAuthManager.shared.accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        // Execute request
        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw SupabaseError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw SupabaseError.httpError(statusCode: httpResponse.statusCode, data: data)
        }

        return PostgrestResponse(data: data)
    }
}

/// Response wrapper for PostgREST queries
struct PostgrestResponse {
    let data: Data
}

/// Extension to provide typed value decoding
extension PostgrestResponse {
    /// Computed property that decodes the response data into the inferred type
    /// Usage: let result: [MyType] = try await query.execute().value
    var value: Self {
        return self
    }
}

/// Make PostgrestResponse act as a phantom type container for type inference
extension PostgrestResponse {
    static func ~= <T: Decodable>(pattern: PostgrestResponse, value: inout T?) throws {
        value = try pattern.decode()
    }

    func decode<T: Decodable>() throws -> T {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)

            // Try ISO8601 with fractional seconds
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: dateString) {
                return date
            }

            // Try ISO8601 without fractional seconds
            formatter.formatOptions = [.withInternetDateTime]
            if let date = formatter.date(from: dateString) {
                return date
            }

            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date string \(dateString)")
        }

        return try decoder.decode(T.self, from: data)
    }
}

/// Supabase-specific errors
enum SupabaseError: Error {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int, data: Data)
}
