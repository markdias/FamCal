//
//  QuickRow.swift
//  FamCal
//
//  Created by Mark Dias on 17/11/2025.
//

import SwiftUI

struct QuickRow<Content: View>: View {
    let icon: String
    let title: String
    let showChevron: Bool
    let color: Color
    @ViewBuilder let content: () -> Content

    init(icon: String, title: String, showChevron: Bool = true, color: Color = .blue, @ViewBuilder content: @escaping () -> Content) {
        self.icon = icon
        self.title = title
        self.showChevron = showChevron
        self.color = color
        self.content = content
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 20)
            
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            content()
                .font(.subheadline)
            
            if showChevron {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.gray.opacity(0.5))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}
