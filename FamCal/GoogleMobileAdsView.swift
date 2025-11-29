//
//  GoogleMobileAdsView.swift
//  FamCal
//
//  Created by Claude Code on 24/11/2025.
//

import SwiftUI
import GoogleMobileAds
import UIKit

/// A SwiftUI wrapper for Google Mobile Ads banner view
/// This component handles the display of banner ads using UIViewRepresentable
/// Ads are only shown to free tier users (hidden for Pro users)
struct GoogleMobileAdsView: UIViewRepresentable {
    let adUnitID: String
    var isProUser: Bool = false

    class Coordinator: NSObject, BannerViewDelegate {
        var parent: GoogleMobileAdsView
        var bannerView: BannerView?

        init(_ parent: GoogleMobileAdsView) {
            self.parent = parent
            super.init()
        }

        // MARK: - BannerViewDelegate methods
        func bannerViewDidReceiveAd(_ bannerView: BannerView) {
            print("✅ Banner ad received: \(self.parent.adUnitID)")
        }

        func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
            print("❌ Banner ad failed: \(error.localizedDescription)")
        }

        func bannerViewDidRecordImpression(_ bannerView: BannerView) {
            print("👁️ Banner ad impression recorded")
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> UIView {
        let containerView = UIView()
        containerView.backgroundColor = .clear
        containerView.translatesAutoresizingMaskIntoConstraints = false

        // Create a fresh banner view with proper ad unit ID
        let bannerView = BannerView(frame: CGRect(x: 0, y: 0, width: 320, height: 50))
        bannerView.adUnitID = adUnitID
        bannerView.rootViewController = getRootViewController()
        bannerView.delegate = context.coordinator
        bannerView.translatesAutoresizingMaskIntoConstraints = false

        // Store reference for delegate callbacks
        context.coordinator.bannerView = bannerView

        containerView.addSubview(bannerView)

        // Add constraints to center banner in container
        NSLayoutConstraint.activate([
            bannerView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            bannerView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            bannerView.widthAnchor.constraint(equalToConstant: 320),
            bannerView.heightAnchor.constraint(equalToConstant: 50)
        ])

        // Load the ad with a Request
        print("📱 Loading ad with unit ID: \(adUnitID)")
        bannerView.load(Request())

        return containerView
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        // Update if needed
    }

    private func getRootViewController() -> UIViewController? {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first else {
            return nil
        }
        return window.rootViewController
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
            VStack {
                GoogleMobileAdsView(adUnitID: adUnitID, isProUser: isProUser)
                    .frame(height: GoogleMobileAdsView.defaultHeight)
                    .background(theme?.cardBackground ?? Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
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
