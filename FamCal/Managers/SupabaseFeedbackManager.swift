//
//  SupabaseFeedbackManager.swift
//  FamCal
//
//  Handles feedback submission to Supabase Edge Function
//

import Foundation
import Combine

class SupabaseFeedbackManager: ObservableObject {
    @Published var isSubmitting = false
    @Published var errorMessage: String?
    @Published var successMessage: String?

    private let functionURL: URL

    init() {
        let baseURL = SupabaseConfig.supabaseURL
        self.functionURL = URL(string: "\(baseURL)/functions/v1/submit-feedback")!
    }

    func submitFeedback(
        type: String,
        message: String,
        email: String? = nil
    ) async {
        DispatchQueue.main.async {
            self.isSubmitting = true
            self.errorMessage = nil
            self.successMessage = nil
        }

        do {
            // Prepare request
            var request = URLRequest(url: functionURL)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer \(SupabaseConfig.supabaseAnonKey)", forHTTPHeaderField: "Authorization")

            // Prepare payload
            let payload: [String: Any?] = [
                "type": type,
                "message": message,
                "email": email
            ]

            request.httpBody = try JSONSerialization.data(withJSONObject: payload)

            // Make request
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw FeedbackError.invalidResponse
            }

            // Parse response
            let decodedResponse = try JSONDecoder().decode(FeedbackResponse.self, from: data)

            DispatchQueue.main.async {
                self.isSubmitting = false

                if httpResponse.statusCode == 200 && decodedResponse.success {
                    self.successMessage = decodedResponse.message ?? "Thank you for your feedback!"
                    print("✅ Feedback submitted successfully")
                } else {
                    self.errorMessage = decodedResponse.error ?? "Failed to submit feedback"
                    print("❌ Feedback submission failed: \(self.errorMessage ?? "")")
                }
            }
        } catch {
            DispatchQueue.main.async {
                self.isSubmitting = false
                self.errorMessage = error.localizedDescription
                print("❌ Feedback submission error: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - Response Model

struct FeedbackResponse: Codable {
    let success: Bool
    let message: String?
    let error: String?
}

// MARK: - Error Handling

enum FeedbackError: LocalizedError {
    case invalidResponse
    case networkError(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from server"
        case .networkError(let message):
            return "Network error: \(message)"
        }
    }
}
