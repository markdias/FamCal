//
//  NoteModels.swift
//  FamCal
//
//  Created by Claude on 2025-12-13.
//

import Foundation

// MARK: - Supabase DTO

struct NoteDTO: Codable {
    let id: String
    let family_id: String
    let member_identifier: String
    let content: String
    let created_at: String?
    let modified_at: String?
    let created_by: String?
}
