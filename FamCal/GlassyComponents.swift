//
//  GlassyComponents.swift
//  FamCal
//
//  Created by Codex on 20/11/2025.
//

import SwiftUI

struct GlassyBackground<Content: View>: View {
    @EnvironmentObject private var themeManager: ThemeManager
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ZStack {
            if themeManager.selectedTheme.id == AppTheme.launchFlow.id {
                themeManager.selectedTheme.backgroundLayer()
                    .ignoresSafeArea()
            } else {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
            }

            content
        }
    }
}

struct GlassyCard: ViewModifier {
    @EnvironmentObject private var themeManager: ThemeManager
    var padding: CGFloat = 16

    func body(content: Content) -> some View {
        if themeManager.selectedTheme.id == AppTheme.launchFlow.id {
            content
                .padding(padding)
                .background(themeManager.selectedTheme.cardBackground)
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(themeManager.selectedTheme.cardStroke, lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
        } else {
            content
                .padding(padding)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
        }
    }
}

struct GlassyRow<Content: View>: View {
    @EnvironmentObject private var themeManager: ThemeManager
    let action: () -> Void
    let content: Content

    init(action: @escaping () -> Void, @ViewBuilder content: () -> Content) {
        self.action = action
        self.content = content()
    }

    var body: some View {
        Button(action: action) {
            if themeManager.selectedTheme.id == AppTheme.launchFlow.id {
                HStack {
                    content
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(themeManager.selectedTheme.textSecondary)
                }
                .padding()
                .background(themeManager.selectedTheme.cardBackground)
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(themeManager.selectedTheme.cardStroke, lineWidth: 1)
                )
            } else {
                HStack {
                    content
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.gray)
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(10)
            }
        }
        .buttonStyle(.plain)
    }
}

extension View {
    func glassyCard(padding: CGFloat = 16) -> some View {
        modifier(GlassyCard(padding: padding))
    }
}

struct GlassyGridItem<Content: View>: View {
    @EnvironmentObject private var themeManager: ThemeManager
    let action: () -> Void
    let content: Content

    init(action: @escaping () -> Void, @ViewBuilder content: () -> Content) {
        self.action = action
        self.content = content()
    }

    var body: some View {
        Button(action: action) {
            if themeManager.selectedTheme.id == AppTheme.launchFlow.id {
                VStack(alignment: .leading, spacing: 12) {
                    content
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(themeManager.selectedTheme.cardBackground)
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(themeManager.selectedTheme.cardStroke, lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    content
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
            }
        }
        .buttonStyle(.plain)
    }
}
