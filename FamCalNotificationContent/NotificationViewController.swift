//
//  NotificationViewController.swift
//  FamCalNotificationContent
//
//  Created by Mark Dias on 01/12/2025.
//

import UIKit
import UserNotifications
import UserNotificationsUI
import MapKit
import CoreLocation

class NotificationViewController: UIViewController, UNNotificationContentExtension {

    private let scrollView = UIScrollView()
    private let contentStackView = UIStackView()
    private let titleLabel = UILabel()

    // Event details (for single event notifications)
    private let timeStackView = UIStackView()
    private let timeIcon = UIImageView()
    private let timeLabel = UILabel()
    private let membersStackView = UIStackView()
    private let membersIcon = UIImageView()
    private let membersLabel = UILabel()
    private let driverStackView = UIStackView()
    private let driverIcon = UIImageView()
    private let driverLabel = UILabel()
    private let locationStackView = UIStackView()
    private let locationIcon = UIImageView()
    private let locationLabel = UILabel()
    private let mapView = MKMapView()
    private let directionsButton = UIButton()

    // Morning brief table
    private let tableView = UITableView()

    private var notification: UNNotification?
    private var isMorningBrief = false
    private var briefEvents: [(title: String, time: String, member: String, location: String?)] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    private func setupUI() {
        view.backgroundColor = .white

        // Setup scroll view
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        // Setup content stack
        contentStackView.axis = .vertical
        contentStackView.spacing = 12
        contentStackView.translatesAutoresizingMaskIntoConstraints = false
        contentStackView.layoutMargins = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        contentStackView.isLayoutMarginsRelativeArrangement = true
        scrollView.addSubview(contentStackView)
        NSLayoutConstraint.activate([
            contentStackView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentStackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentStackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentStackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentStackView.widthAnchor.constraint(equalTo: scrollView.widthAnchor)
        ])

        // Setup table view for morning brief
        setupTableView()

        // Setup title
        titleLabel.font = UIFont.systemFont(ofSize: 18, weight: .bold)
        titleLabel.numberOfLines = 2
        contentStackView.addArrangedSubview(titleLabel)

        // Setup time row
        setupIconRow(timeStackView, icon: timeIcon, label: timeLabel, imageName: "clock.fill")
        contentStackView.addArrangedSubview(timeStackView)

        // Setup members row
        setupIconRow(membersStackView, icon: membersIcon, label: membersLabel, imageName: "person.2.fill")
        contentStackView.addArrangedSubview(membersStackView)
        membersStackView.isHidden = true

        // Setup driver row
        setupIconRow(driverStackView, icon: driverIcon, label: driverLabel, imageName: "car.fill")
        contentStackView.addArrangedSubview(driverStackView)
        driverStackView.isHidden = true

        // Setup location row
        setupIconRow(locationStackView, icon: locationIcon, label: locationLabel, imageName: "location.fill")
        contentStackView.addArrangedSubview(locationStackView)
        locationStackView.isHidden = true

        // Setup map
        mapView.translatesAutoresizingMaskIntoConstraints = false
        mapView.heightAnchor.constraint(equalToConstant: 128).isActive = true
        contentStackView.addArrangedSubview(mapView)
        mapView.isHidden = true

        // Setup directions button
        var config = UIButton.Configuration.filled()
        config.title = "Get Directions"
        directionsButton.configuration = config
        directionsButton.addTarget(self, action: #selector(handleGetDirections), for: .touchUpInside)
        contentStackView.addArrangedSubview(directionsButton)
        directionsButton.translatesAutoresizingMaskIntoConstraints = false
        directionsButton.heightAnchor.constraint(equalToConstant: 44).isActive = true
        directionsButton.isHidden = true
    }

    private func setupTableView() {
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(EventTableViewCell.self, forCellReuseIdentifier: "EventCell")
        tableView.separatorStyle = .singleLine
        tableView.separatorColor = UIColor.systemGray5
        tableView.backgroundColor = .white
        tableView.isScrollEnabled = true
        tableView.layer.borderColor = UIColor.systemGray4.cgColor
        tableView.layer.borderWidth = 0.5
        tableView.layer.cornerRadius = 8
        tableView.clipsToBounds = true
    }

    private func setupIconRow(_ stackView: UIStackView, icon: UIImageView, label: UILabel, imageName: String) {
        stackView.axis = .horizontal
        stackView.spacing = 8
        stackView.alignment = .center

        icon.image = UIImage(systemName: imageName)
        icon.tintColor = .systemBlue
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.widthAnchor.constraint(equalToConstant: 20).isActive = true
        icon.heightAnchor.constraint(equalToConstant: 20).isActive = true
        stackView.addArrangedSubview(icon)

        label.font = UIFont.systemFont(ofSize: 13)
        label.numberOfLines = 2
        stackView.addArrangedSubview(label)
    }

    func didReceive(_ notification: UNNotification) {
        self.notification = notification
        let content = notification.request.content
        let userInfo = content.userInfo

        // Check if this is a morning brief notification
        isMorningBrief = (userInfo["isMorningBrief"] as? Bool) ?? false

        // Set title
        titleLabel.text = content.title
        contentStackView.addArrangedSubview(titleLabel)

        if isMorningBrief {
            displayMorningBrief(userInfo: userInfo)
        } else {
            displayEventNotification(userInfo: userInfo)
        }
    }

    private func displayMorningBrief(userInfo: [AnyHashable: Any]) {
        guard let eventCount = userInfo["eventCount"] as? Int, eventCount > 0 else {
            return
        }

        // Parse events from userInfo
        for i in 0..<eventCount {
            if let title = userInfo["event_\(i)_title"] as? String {
                let time = userInfo["event_\(i)_time"] as? String ?? "TBD"
                let member = userInfo["event_\(i)_member"] as? String ?? "Family"
                let location = userInfo["event_\(i)_location"] as? String

                briefEvents.append((title: title, time: time, member: member, location: location))
            }
        }

        // Add table view to content stack
        if !briefEvents.isEmpty {
            let headerLabel = UILabel()
            headerLabel.text = "Today's Events"
            headerLabel.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
            headerLabel.textColor = .label
            contentStackView.addArrangedSubview(headerLabel)

            contentStackView.addArrangedSubview(tableView)

            // Set max height for table (3 visible cells + scroll for more)
            let maxTableHeight: CGFloat = briefEvents.count <= 3 ? CGFloat(briefEvents.count * 60) : 260
            tableView.heightAnchor.constraint(equalToConstant: maxTableHeight).isActive = true
            tableView.reloadData()
        }
    }

    private func displayEventNotification(userInfo: [AnyHashable: Any]) {
        // Extract time from body
        if let body = notification?.request.content.body {
            if let timeString = extractTimeFromBody(body) {
                timeLabel.text = timeString
            }
        }

        // Set members
        if let memberNames = userInfo["familyMembers"] as? String, !memberNames.isEmpty {
            membersLabel.text = "With: \(memberNames)"
            membersStackView.isHidden = false
        }

        // Set driver
        if let drivers = userInfo["drivers"] as? String, !drivers.isEmpty {
            driverLabel.text = "Driver: \(drivers)"
            driverStackView.isHidden = false
        }

        // Set location and map
        if let location = userInfo["location"] as? String, !location.isEmpty {
            locationLabel.text = location
            locationStackView.isHidden = false
            mapView.isHidden = false
            directionsButton.isHidden = false
            geocodeAndShowLocation(location)
        }
    }

    private func extractTimeFromBody(_ body: String) -> String? {
        let lines = body.split(separator: "\n")
        return lines.first.map(String.init)
    }

    private func geocodeAndShowLocation(_ address: String) {
        let geocoder = CLGeocoder()
        geocoder.geocodeAddressString(address) { [weak self] placemarks, _ in
            guard let self = self, let placemark = placemarks?.first,
                  let location = placemark.location else {
                self?.showDefaultLocation()
                return
            }
            DispatchQueue.main.async {
                self.showLocationOnMap(location.coordinate)
            }
        }
    }

    private func showLocationOnMap(_ coordinate: CLLocationCoordinate2D) {
        let region = MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        )
        mapView.setRegion(region, animated: true)

        let annotation = MKPointAnnotation()
        annotation.coordinate = coordinate
        annotation.title = notification?.request.content.userInfo["location"] as? String
        mapView.addAnnotation(annotation)
    }

    private func showDefaultLocation() {
        let defaultCoordinate = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        showLocationOnMap(defaultCoordinate)
    }

    @objc private func handleGetDirections() {
        guard let location = notification?.request.content.userInfo["location"] as? String else {
            return
        }

        let geocoder = CLGeocoder()
        geocoder.geocodeAddressString(location) { placemarks, _ in
            guard let coordinate = placemarks?.first?.location?.coordinate else {
                return
            }

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
}

// MARK: - UITableViewDataSource

extension NotificationViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return briefEvents.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "EventCell", for: indexPath) as! EventTableViewCell
        let event = briefEvents[indexPath.row]
        cell.configure(title: event.title, time: event.time, member: event.member, location: event.location)
        return cell
    }
}

// MARK: - UITableViewDelegate

extension NotificationViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 60
    }
}

// MARK: - EventTableViewCell

class EventTableViewCell: UITableViewCell {
    private let titleLabel = UILabel()
    private let timeLabel = UILabel()
    private let memberLabel = UILabel()
    private let locationLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        backgroundColor = .white
        selectionStyle = .none

        let mainStackView = UIStackView()
        mainStackView.axis = .vertical
        mainStackView.spacing = 4
        mainStackView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(mainStackView)

        // Setup title label
        titleLabel.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        titleLabel.textColor = .label
        titleLabel.numberOfLines = 1
        mainStackView.addArrangedSubview(titleLabel)

        // Setup details stack
        let detailsStackView = UIStackView()
        detailsStackView.axis = .horizontal
        detailsStackView.spacing = 12
        detailsStackView.distribution = .fillProportionally

        // Time column
        timeLabel.font = UIFont.systemFont(ofSize: 12, weight: .regular)
        timeLabel.textColor = .systemBlue
        timeLabel.numberOfLines = 1
        detailsStackView.addArrangedSubview(timeLabel)

        // Member column
        memberLabel.font = UIFont.systemFont(ofSize: 12, weight: .regular)
        memberLabel.textColor = .secondaryLabel
        memberLabel.numberOfLines = 1
        detailsStackView.addArrangedSubview(memberLabel)

        // Location column
        locationLabel.font = UIFont.systemFont(ofSize: 12, weight: .regular)
        locationLabel.textColor = .systemGray
        locationLabel.numberOfLines = 1
        detailsStackView.addArrangedSubview(locationLabel)

        mainStackView.addArrangedSubview(detailsStackView)

        // Constraints
        NSLayoutConstraint.activate([
            mainStackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            mainStackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            mainStackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            mainStackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8)
        ])
    }

    func configure(title: String, time: String, member: String, location: String?) {
        titleLabel.text = title
        timeLabel.text = "⏰ \(time)"
        memberLabel.text = "👤 \(member)"
        if let location = location, !location.isEmpty {
            locationLabel.text = "📍 \(location)"
        } else {
            locationLabel.text = ""
        }
    }
}
