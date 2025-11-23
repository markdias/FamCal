//
//  ThemeSettingsView.swift
//  FamCal
//
//  Created by Codex on 20/11/2025.
//

import SwiftUI

struct ThemeSettingsView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss
    
    private var theme: AppTheme { themeManager.selectedTheme }

    var body: some View {
        ZStack {
            theme.backgroundLayer().ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("Pick a theme")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(theme.textSecondary)

                    VStack(spacing: 18) {
                        ForEach(AppTheme.allThemes) { theme in
                            Button(action: {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                                    themeManager.select(theme: theme)
                                }
                            }) {
                                ThemeOptionCard(theme: theme, isSelected: themeManager.selectedTheme.id == theme.id)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Select \(theme.displayName) theme")
                            .accessibilityHint(theme.description)
                            .accessibilityAddTraits(themeManager.selectedTheme.id == theme.id ? .isSelected : [])
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 28)
                .padding(.bottom, 48)
            }
        }
        .navigationTitle("Themes")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct ThemeOptionCard: View {
    @EnvironmentObject private var themeManager: ThemeManager
    let theme: AppTheme
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(theme.displayName)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(theme.textPrimary)

                    Text(theme.description)
                        .font(.system(size: 13))
                        .foregroundColor(theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                if theme.id == AppTheme.launchFlow.id {
                    Text("New")
                        .font(.system(size: 11, weight: .bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(theme.accentColor.opacity(0.9))
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                }
            }

            ThemePreviewCanvas(theme: theme)
                .frame(height: 150)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(isSelected ? theme.accentColor.opacity(0.9) : Color.clear, lineWidth: 2)
                )
                .overlay(alignment: .topTrailing) {
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(theme.accentColor)
                            .offset(x: -12, y: 12)
                            .shadow(color: Color.black.opacity(0.15), radius: 6, y: 3)
                    }
                }
        }
        .padding(20)
        .background(
            theme.backgroundLayer()
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(theme.cardStroke.opacity(0.4), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
    }
}

private struct ThemePreviewCanvas: View {
    let theme: AppTheme

    var body: some View {
        ZStack {
            theme.backgroundLayer()
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

            VStack(spacing: 14) {
                HStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(theme.cardBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(theme.cardStroke, lineWidth: 1)
                        )
                        .overlay(alignment: .topLeading) {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(theme.accentColor.opacity(0.5))
                                .frame(width: 42, height: 32)
                                .padding(12)
                        }
                        .overlay(alignment: .bottomLeading) {
                            VStack(alignment: .leading, spacing: 4) {
                                Capsule()
                                    .fill(theme.textPrimary.opacity(0.8))
                                    .frame(width: 100, height: 10)
                                Capsule()
                                    .fill(theme.textSecondary.opacity(0.7))
                                    .frame(width: 70, height: 6)
                            }
                            .padding(14)
                        }
                        .frame(width: 160, height: 110)

                    Spacer()

                    VStack(spacing: 12) {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(theme.floatingControlsBackground)
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(theme.floatingControlsBorder, lineWidth: 1)
                            )
                            .frame(width: 80, height: 50)

                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(theme.accentFillStyle())
                            .frame(width: 80, height: 50)
                    }
                }
                .padding(.horizontal, 14)
            }
        }
    }
}

#Preview {
    ThemeSettingsView()
        .environmentObject(ThemeManager())
}
