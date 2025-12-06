//
//  DriverWrapper.swift
//  FamCal
//
//  Created by Mark Dias on 20/11/2025.
//

import Foundation

/// Wrapper to handle both regular Driver objects and FamilyMember objects as drivers
enum DriverWrapper: Identifiable, Equatable {
    case regular(Driver)
    case familyMember(FamilyMember)

    var id: UUID {
        switch self {
        case .regular(let driver):
            return driver.id ?? UUID()
        case .familyMember(let member):
            return member.id ?? UUID()
        }
    }

    var name: String {
        switch self {
        case .regular(let driver):
            return driver.name ?? "Unknown Driver"
        case .familyMember(let member):
            return member.name ?? "Unknown Member"
        }
    }

    var phone: String? {
        switch self {
        case .regular(let driver):
            return driver.phone
        case .familyMember:
            return nil // Family members don't have direct phone in Driver
        }
    }

    var isFamilyMember: Bool {
        switch self {
        case .familyMember:
            return true
        case .regular:
            return false
        }
    }

    var familyMemberId: UUID? {
        switch self {
        case .familyMember(let member):
            return member.id
        case .regular:
            return nil
        }
    }

    // Get the actual Driver object if this is a regular driver
    var asDriver: Driver? {
        switch self {
        case .regular(let driver):
            return driver
        case .familyMember:
            return nil
        }
    }

    // Get the actual FamilyMember object if this is a family member
    var asFamilyMember: FamilyMember? {
        switch self {
        case .familyMember(let member):
            return member
        case .regular:
            return nil
        }
    }
}
