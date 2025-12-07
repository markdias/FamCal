//
//  SystemSettingsView.swift
//  FamCal
//
//  Created by Mark Dias on 21/11/2025.
//

import SwiftUI
import CoreData

struct SystemSettingsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "F2F2F7").ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        VStack(spacing: 0) {
                            NavigationLink(destination: AppSettingsView()) {
                                SettingsMenuRow(
                                    iconName: "square.grid.2x2",
                                    iconColor: Color.blue,
                                    title: "App Settings",
                                    subtitle: "Default screen, refresh, maps"
                                )
                            }
                            
                            Divider().padding(.leading, 76)

                            NavigationLink(destination: ThemeSettingsView()) {
                                SettingsMenuRow(
                                    iconName: "paintbrush",
                                    iconColor: Color.purple,
                                    title: "Theme",
                                    subtitle: themeManager.selectedTheme.displayName
                                )
                            }
                            
                            Divider().padding(.leading, 76)

                            NavigationLink(destination: NotificationSettingsView().environment(\.managedObjectContext, viewContext)) {
                                SettingsMenuRow(
                                    iconName: "bell.fill",
                                    iconColor: Color.orange,
                                    title: "Notifications",
                                    subtitle: "Event alerts and morning brief"
                                )
                            }
                            
                            Divider().padding(.leading, 76)

                            NavigationLink(destination: PermissionsView()) {
                                SettingsMenuRow(
                                    iconName: "lock.fill",
                                    iconColor: Color.red,
                                    title: "Permissions",
                                    subtitle: "Calendar and contacts access"
                                )
                            }
                        }
                        .background(Color.white)
                        .cornerRadius(12)
                        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                        .padding(.horizontal, 16)
                        .padding(.top, 24)

                        Spacer()
                    }
                }
            }
            .navigationTitle("System Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.black)
                    }
                }
            }
        }
    }
}

// MARK: - Settings Menu Row
private struct SettingsMenuRow: View {
    @EnvironmentObject private var themeManager: ThemeManager
    let iconName: String
    let iconColor: Color
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: iconName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 44, height: 44)
                .background(iconColor)
                .cornerRadius(12)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)

                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundColor(.gray)
            }

            Spacer()

            Image(systemName: "pencil")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.gray.opacity(0.5))
        }
        .padding(16)
    }
}

#Preview {
    SystemSettingsView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        .environmentObject(ThemeManager())
}
