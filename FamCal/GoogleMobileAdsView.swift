//
//  GoogleMobileAdsView.swift
//  FamCal
//
//  Created by Claude Code on 24/11/2025.
//

import SwiftUI
// import GoogleMobileAds
// Temporarily disabled due to pod configuration issues - will be re-enabled once pod setup is fixed

/// A SwiftUI wrapper for Google Mobile Ads banner view
/// This component handles the display of banner ads using UIViewRepresentable
/// Ads are only shown to free tier users (hidden for Pro users)
///
/// NOTE: This view is currently disabled until GoogleMobileAds SDK is properly configured
struct GoogleMobileAdsView: UIViewRepresentable {
    let adUnitID: String
    var isProUser: Bool = false

    class Coordinator: NSObject {
        var parent: GoogleMobileAdsView

        init(_ parent: GoogleMobileAdsView) {
            self.parent = parent
        }

        // MARK: - Placeholder methods (GoogleMobileAds SDK integration disabled)
        // These would normally implement BannerViewDelegate
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> UIView {
        // Return empty view - ads disabled until GoogleMobileAds pod is fixed
        let emptyView = UIView()
        emptyView.backgroundColor = .clear
        emptyView.translatesAutoresizingMaskIntoConstraints = false
        emptyView.heightAnchor.constraint(equalToConstant: 0).isActive = true
        return emptyView
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        // No-op - ads are currently disabled
    }

    static var defaultHeight: CGFloat = 50
}

/// A simple container for the banner ad with proper sizing and theming
struct AdBannerContainer: View {
    let adUnitID: String
    var isProUser: Bool = false
    var theme: AppTheme?

    var body: some View {
        if !isProUser {
            GoogleMobileAdsView(adUnitID: adUnitID, isProUser: isProUser)
                .frame(height: GoogleMobileAdsView.defaultHeight)
                .background(theme?.cardBackground ?? Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
        }
    }
}

#Preview {
    AdBannerContainer(
        adUnitID: "ca-app-pub-3940256099942544/6300978111",
        isProUser: false
    )
}
