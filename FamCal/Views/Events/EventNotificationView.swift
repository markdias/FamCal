//
//  EventNotificationView.swift
//  FamCal
//
//  Created by Mark Dias on 21/11/2025.
//

import SwiftUI
import MapKit
import UserNotifications
import CoreLocation
import Contacts

struct EventNotificationView: View {
    let title: String
    let time: String
    let memberNames: String?
    let driver: String?
    let location: String?
    let meetingLink: String?

    @State private var region: MKCoordinateRegion = MKCoordinateRegion()
    @State private var isLoadingLocation = false
    @State private var locationCoordinate: CLLocationCoordinate2D? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Title and Time
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.black)
                    .lineLimit(2)

                HStack(spacing: 4) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.blue)
                    Text(time)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.gray)
                }
            }

            // Members
            if let memberNames = memberNames, !memberNames.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.blue)
                    Text(memberNames)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(.black)
                        .lineLimit(2)
                }
            }

            // Driver
            if let driver = driver, !driver.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "car.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.blue)
                    Text("Driver: \(driver)")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(.black)
                        .lineLimit(1)
                }
            }

            // Location with Map
            if let location = location, !location.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 4) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.blue)
                        Text(location)
                            .font(.system(size: 13, weight: .regular))
                            .foregroundColor(.black)
                            .lineLimit(1)
                    }

                    // Map Preview
                    if let coordinate = locationCoordinate {
                        MapPreview(coordinate: coordinate, locationName: location)
                            .frame(height: 150)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    } else {
                        // Loading or placeholder
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.gray.opacity(0.2))
                            ProgressView()
                                .tint(.blue)
                        }
                        .frame(height: 150)
                    }

                    // Route Planning Button
                    Button(action: openMaps) {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.triangle.turn.up.right.fill")
                                .font(.system(size: 13, weight: .semibold))
                            Text("Get Directions")
                                .font(.system(size: 14, weight: .semibold))
                            Spacer()
                            Image(systemName: "pencil")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 12)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }

                    if let meetingLink = meetingLink,
                       let destination = MeetingLinkHelper.normalizedURL(from: meetingLink) {
                        Link(destination: destination) {
                            HStack(spacing: 8) {
                                Image(systemName: "video.fill")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.blue)
                                Text(MeetingLinkHelper.displayLabel(for: meetingLink))
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.blue)
                                Spacer()
                                Image(systemName: "pencil")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(.blue)
                            }
                            .padding(.vertical, 10)
                            .padding(.horizontal, 12)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(8)
                        }
                    }
                }
                .onAppear {
                    geocodeLocation(location)
                }
            }
        }
        .padding(16)
        .background(Color.white)
    }

    private func geocodeLocation(_ address: String) {
        // For now, we'll show a default location
        // In a full implementation, this would use MKLocalSearch or another geocoding method
        guard locationCoordinate == nil else { return }

        isLoadingLocation = true

        // Simulate geocoding - in production you'd use MKLocalSearch
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.isLoadingLocation = false
            // Default to a general location (could be customized based on address analysis)
            self.locationCoordinate = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
            self.region = MKCoordinateRegion(
                center: self.locationCoordinate!,
                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
            )
        }
    }

    private func openMaps() {
        guard let coordinate = locationCoordinate else { return }

        let placemark = MKPlacemark(coordinate: coordinate)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = location

        let launchOptions: [String: Any] = [
            MKLaunchOptionsMapCenterKey: NSValue(mkCoordinate: coordinate),
            MKLaunchOptionsMapSpanKey: NSValue(mkCoordinateSpan: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)),
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
        ]

        mapItem.openInMaps(launchOptions: launchOptions)
    }
}

// MARK: - MapPreview

struct MapPreview: View {
    let coordinate: CLLocationCoordinate2D
    let locationName: String

    @State private var region: MKCoordinateRegion

    init(coordinate: CLLocationCoordinate2D, locationName: String) {
        self.coordinate = coordinate
        self.locationName = locationName
        _region = State(initialValue: MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        ))
    }

    var body: some View {
        Map(position: .constant(.region(region))) {
            Annotation(locationName, coordinate: coordinate) {
                Image(systemName: "mappin.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.red)
            }
        }
        .mapStyle(.standard(elevation: .flat))
    }
}

// MARK: - Preview

#Preview {
    EventNotificationView(
        title: "Family Dinner",
        time: "6:30 PM",
        memberNames: "John, Sarah, Michael",
        driver: "John",
        location: "123 Main St, San Francisco, CA",
        meetingLink: "https://zoom.us/j/1234567890"
    )
}
