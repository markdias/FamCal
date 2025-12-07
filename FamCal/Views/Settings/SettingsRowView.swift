//
//  SettingsRowView.swift
//  FamCal
//
//  Created by Codex on 21/11/2025.
//

import SwiftUI

struct SettingsRowView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    let iconName: String
    let title: String
    var showChevron: Bool = true
    
    private var theme: AppTheme { themeManager.selectedTheme }
    private var primaryTextColor: Color { theme.textPrimary }
    private var secondaryTextColor: Color { theme.textSecondary }
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: iconName)
                .font(.system(size: 20))
                .foregroundColor(secondaryTextColor)
                .frame(width: 24, height: 24)

            Text(title)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(primaryTextColor)

            Spacer()

            if showChevron {
                Image(systemName: "pencil")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(secondaryTextColor.opacity(0.6))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

#Preview {
    VStack {
        SettingsRowView(iconName: "person.circle", title: "Profile")
        SettingsRowView(iconName: "lock", title: "Password")
    }
    .padding()
    .environmentObject(ThemeManager())
}
