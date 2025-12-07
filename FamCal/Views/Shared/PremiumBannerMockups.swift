//
//  PremiumBannerMockups.swift
//  FamCal
//
//  Design mockups for FamCal Pro banner redesign
//

import SwiftUI

// MARK: - Option 1: Compact Status Card
struct Option1_CompactStatusCard: View {
    let isPro: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            if isPro {
                // Compact version for Pro users
                HStack(spacing: 12) {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.yellow)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("FamCal Pro Active")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.primary)
                        Text("All features unlocked")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.green)
                }
                .padding(16)
                .background(Color(.systemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.green.opacity(0.3), lineWidth: 1.5)
                )
                .cornerRadius(12)
            } else {
                // Prominent version for Free users
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 10) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 22))
                            .foregroundColor(.yellow)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Unlock FamCal Pro")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.primary)
                            Text("Unlimited family, themes & more")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }

                        Spacer()
                    }

                    HStack(spacing: 8) {
                        FeaturePill(icon: "person.3.fill", text: "Unlimited")
                        FeaturePill(icon: "paintpalette.fill", text: "Themes")
                        FeaturePill(icon: "square.grid.2x2.fill", text: "Widgets")
                    }
                }
                .padding(16)
                .background(
                    LinearGradient(
                        colors: [Color.purple.opacity(0.15), Color.blue.opacity(0.15)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.purple.opacity(0.3), lineWidth: 1.5)
                )
                .cornerRadius(16)
            }
        }
        .buttonStyle(.plain)
    }
}

struct FeaturePill: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10))
            Text(text)
                .font(.system(size: 11, weight: .medium))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.purple.opacity(0.6))
        .cornerRadius(8)
    }
}

// MARK: - Option 2: Feature Highlights Banner
struct Option2_FeatureHighlights: View {
    let isPro: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 0) {
                // Left side - Icon column
                VStack(spacing: 8) {
                    Image(systemName: isPro ? "checkmark.seal.fill" : "star.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.yellow)
                }
                .frame(width: 60)

                // Middle - Content
                VStack(alignment: .leading, spacing: 8) {
                    Text("FamCal Pro")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)

                    if isPro {
                        Text("Premium features active")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white.opacity(0.9))
                    } else {
                        HStack(spacing: 6) {
                            HighlightBadge(text: "Unlimited Family")
                            HighlightBadge(text: "All Themes")
                            HighlightBadge(text: "No Ads")
                        }
                    }
                }

                Spacer()

                // Right side - CTA
                VStack {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
            .background(
                LinearGradient(
                    colors: isPro
                        ? [Color.green.opacity(0.8), Color.teal.opacity(0.8)]
                        : [Color(red: 0.6, green: 0.3, blue: 0.9), Color(red: 0.3, green: 0.5, blue: 1.0)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }
}

struct HighlightBadge: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Color.white.opacity(0.25))
            .cornerRadius(6)
    }
}

// MARK: - Option 3: Glassmorphic Card
struct Option3_Glassmorphic: View {
    let isPro: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: isPro
                        ? [Color.green.opacity(0.3), Color.teal.opacity(0.3)]
                        : [Color.purple.opacity(0.3), Color.blue.opacity(0.3)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                // Glassmorphic overlay
                Color.white.opacity(0.15)
                    .background(.ultraThinMaterial)

                // Content
                HStack(spacing: 16) {
                    // Icon with glow
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.2))
                            .frame(width: 50, height: 50)
                            .blur(radius: 10)

                        Image(systemName: isPro ? "crown.fill" : "sparkles")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(.white)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("FamCal Pro")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)

                        Text(isPro ? "Premium Active" : "Unlock Premium Features")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white.opacity(0.85))
                    }

                    Spacer()

                    VStack(spacing: 4) {
                        Image(systemName: isPro ? "checkmark.circle.fill" : "arrow.right.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.white)

                        if !isPro {
                            Text("View")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.white.opacity(0.9))
                        }
                    }
                }
                .padding(20)
            }
            .frame(height: 90)
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.15), radius: 15, x: 0, y: 8)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Option 4: Split State Design
struct Option4_SplitState: View {
    let isPro: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            if isPro {
                // Minimal badge for Pro users
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.white)

                    Text("Pro Active")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)

                    Spacer()

                    Text("Manage")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    LinearGradient(
                        colors: [Color.green, Color.teal],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(12)
            } else {
                // Compact card for Free users
                HStack(spacing: 14) {
                    // Icon
                    Image(systemName: "sparkles")
                        .font(.system(size: 22))
                        .foregroundColor(Color(red: 1.0, green: 0.84, blue: 0.4))

                    // Content
                    VStack(alignment: .leading, spacing: 3) {
                        Text("FamCal Pro")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(.white)

                        Text("Unlimited family, themes & more")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.85))

                        Text("3-day free trial")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(Color(red: 1.0, green: 0.84, blue: 0.4))
                    }

                    Spacer()

                    // CTA
                    VStack(spacing: 2) {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 22))
                            .foregroundColor(.white)

                        Text("View")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.white.opacity(0.9))
                    }
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(
                        colors: [
                            Color(red: 0.22, green: 0.24, blue: 0.30),
                            Color(red: 0.30, green: 0.34, blue: 0.42)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .cornerRadius(16)
                .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
            }
        }
        .buttonStyle(.plain)
    }
}

struct MiniFeatureCard: View {
    let icon: String
    let title: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(.white)

            Text(title)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(.white.opacity(0.95))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 60)
        .background(Color.white.opacity(0.15))
        .cornerRadius(10)
    }
}

// MARK: - Option 5: Interactive Feature Carousel
struct Option5_FeatureCarousel: View {
    let isPro: Bool
    let action: () -> Void
    @State private var currentFeature = 0

    let features = [
        ("person.3.fill", "Unlimited Family Members"),
        ("paintpalette.fill", "Premium Themes"),
        ("square.grid.2x2.fill", "Home Screen Widgets"),
        ("mappin.circle.fill", "Saved Places"),
        ("car.fill", "Driver Coordination")
    ]

    var body: some View {
        Button(action: action) {
            if isPro {
                // Stats card for Pro users
                HStack(spacing: 16) {
                    Image(systemName: "chart.bar.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.white)
                        .frame(width: 40)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("FamCal Pro Active")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)

                        Text("All premium features unlocked")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.85))
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(18)
                .background(
                    LinearGradient(
                        colors: [Color.green.opacity(0.9), Color.teal.opacity(0.9)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(16)
            } else {
                // Carousel for Free users
                VStack(spacing: 12) {
                    HStack {
                        Text("FamCal Pro")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)

                        Spacer()

                        Text("View All")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white.opacity(0.9))
                    }

                    // Feature showcase
                    TabView(selection: $currentFeature) {
                        ForEach(0..<features.count, id: \.self) { index in
                            HStack(spacing: 12) {
                                Image(systemName: features[index].0)
                                    .font(.system(size: 28))
                                    .foregroundColor(.yellow)
                                    .frame(width: 50)

                                Text(features[index].1)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.white)

                                Spacer()
                            }
                            .tag(index)
                        }
                    }
                    .tabViewStyle(PageTabViewStyle(indexDisplayMode: .always))
                    .frame(height: 50)

                    Text("Start 3-day free trial")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.85))
                }
                .padding(18)
                .background(
                    LinearGradient(
                        colors: [
                            Color(red: 0.4, green: 0.3, blue: 0.9),
                            Color(red: 0.2, green: 0.5, blue: 1.0)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .cornerRadius(18)
                .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview
struct PremiumBannerMockups_Previews: PreviewProvider {
    static var previews: some View {
        ScrollView {
            VStack(spacing: 32) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Option 1: Compact Status Card")
                        .font(.headline)
                    Text("Free Plan")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Option1_CompactStatusCard(isPro: false, action: {})

                    Text("Pro Active")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Option1_CompactStatusCard(isPro: true, action: {})
                }

                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Text("Option 2: Feature Highlights")
                        .font(.headline)
                    Text("Free Plan")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Option2_FeatureHighlights(isPro: false, action: {})

                    Text("Pro Active")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Option2_FeatureHighlights(isPro: true, action: {})
                }

                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Text("Option 3: Glassmorphic")
                        .font(.headline)
                    Text("Free Plan")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Option3_Glassmorphic(isPro: false, action: {})

                    Text("Pro Active")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Option3_Glassmorphic(isPro: true, action: {})
                }

                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Text("Option 4: Split State")
                        .font(.headline)
                    Text("Free Plan")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Option4_SplitState(isPro: false, action: {})

                    Text("Pro Active")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Option4_SplitState(isPro: true, action: {})
                }

                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Text("Option 5: Feature Carousel")
                        .font(.headline)
                    Text("Free Plan")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Option5_FeatureCarousel(isPro: false, action: {})

                    Text("Pro Active")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Option5_FeatureCarousel(isPro: true, action: {})
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
    }
}
