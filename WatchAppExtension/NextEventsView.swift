import SwiftUI
import WatchConnectivity

final class WatchEventsViewModel: NSObject, ObservableObject {
    enum State {
        case loading
        case success([WatchMemberEvent])
        case error(String)
    }

    @Published private(set) var state: State = .loading

    private let session: WCSession?
    private let decoder: JSONDecoder

    override init() {
        if WCSession.isSupported() {
            session = .default
        } else {
            session = nil
        }
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        super.init()

        // Activate WatchConnectivity session
        session?.delegate = self
        session?.activate()

        print("⌚ WatchEventsViewModel initialized")
        if let session = session {
            print("⌚ WCSession state:")
            print("  - isSupported: true")
            print("  - activationState: \(session.activationState.rawValue)")
            print("  - isReachable: \(session.isReachable)")
        }

        // Don't request events here - wait for WCSessionDelegate callback
    }

    func requestEvents() {
        guard let session else {
            setState(.error("Watch connectivity is unavailable."))
            return
        }

        guard session.isReachable else {
            setState(.error("Open FamCal on your iPhone to sync."))
            return
        }

        setState(.loading)

        print("⌚ Requesting events from iPhone via WatchConnectivity")

        // Add a timeout to prevent infinite loading
        let timeoutTask = Task {
            try? await Task.sleep(nanoseconds: 10_000_000_000) // 10 second timeout
            if case .loading = self.state {
                self.setState(.error("Request timed out. Check iPhone connection."))
            }
        }

        // Request member names to test basic communication
        session.sendMessage(
            ["action": "getMembers"],
            replyHandler: { [weak self] reply in
                print("⌚ Received reply from iPhone: \(reply.keys)")
                timeoutTask.cancel()
                self?.handleReply(reply)
            },
            errorHandler: { [weak self] error in
                print("⌚ Error sending message: \(error.localizedDescription)")
                timeoutTask.cancel()
                self?.setState(.error("Connection failed: \(error.localizedDescription)"))
            }
        )
    }

    private func handleReply(_ response: [String: Any]) {
        print("⌚ Processing reply: \(response.keys.sorted())")

        guard let ok = response["ok"] as? String, ok == "yes" else {
            let error = response["error"] as? String ?? "Unknown error"
            print("⚠️ iPhone returned error: \(error)")
            setState(.error(error))
            return
        }

        guard let membersString = response["members"] as? String else {
            print("⚠️ No members in response")
            setState(.error("Invalid response format"))
            return
        }

        let memberNames = membersString.split(separator: ",").map(String.init)
        print("⌚ Successfully received \(memberNames.count) members: \(memberNames)")

        // Create placeholder events for each member (no event data yet)
        var events: [WatchMemberEvent] = []
        for name in memberNames {
            let event = WatchMemberEvent(
                memberId: UUID(),
                memberName: name,
                memberColorHex: "#007AFF",
                calendarColorHex: "#007AFF",
                calendarTitle: nil,
                eventTitle: nil,
                eventIdentifier: nil,
                startDate: nil,
                endDate: nil,
                location: nil,
                attendees: []
            )
            events.append(event)
        }

        setState(.success(events))
    }

    private func setState(_ newState: State) {
        Task { @MainActor in
            self.state = newState
        }
    }
}

extension WatchEventsViewModel: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        print("⌚ WCSession activation completed: \(activationState.rawValue)")
        if let error {
            print("⌚ WCSession activation error: \(error.localizedDescription)")
            state = .error(error.localizedDescription)
        } else if activationState == .activated {
            print("⌚ WCSession activated, requesting events")
            requestEvents()
        }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        print("⌚ Session reachability changed: isReachable=\(session.isReachable)")
        if session.isReachable {
            requestEvents()
        }
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        print("⌚ Received message from phone: \(message.keys)")
        if let action = message["command"] as? String, action == "refresh" {
            requestEvents()
        }
    }
}

struct NextEventsView: View {
    @StateObject private var viewModel = WatchEventsViewModel()

    var body: some View {
        Group {
            switch viewModel.state {
            case .loading:
                ProgressView()
                    .padding()
            case .error(let message):
                VStack(spacing: 6) {
                    Text(message)
                        .multilineTextAlignment(.center)
                    Button("Retry", action: viewModel.requestEvents)
                }
                .padding(8)
            case .success(let events):
                if events.isEmpty {
                    VStack(spacing: 6) {
                        Text("No upcoming events yet.")
                        Button("Refresh", action: viewModel.requestEvents)
                    }
                    .padding(8)
                } else {
                    TabView {
                        ForEach(events) { event in
                            MemberEventCard(memberEvent: event)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .automatic))
                }
            }
        }
        .navigationTitle("Next Events")
    }
}

private struct MemberEventCard: View {
    let memberEvent: WatchMemberEvent

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Circle()
                    .fill(Color(hex: memberEvent.memberColorHex))
                    .frame(width: 12, height: 12)
                Text(memberEvent.memberName)
                    .font(.headline)
            }

            if memberEvent.hasEvent {
                Text(memberEvent.eventTitle ?? "Event")
                    .font(.title3)
                    .bold()

                if let startDate = memberEvent.startDate {
                    Text(Self.timeFormatter.string(from: startDate))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                if let calendarTitle = memberEvent.calendarTitle {
                    Label(calendarTitle, systemImage: "calendar")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                if let location = memberEvent.location, !location.isEmpty {
                    Label(location, systemImage: "location")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                if !memberEvent.attendees.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "person.2.fill")
                        Text(memberEvent.attendees.joined(separator: ", "))
                            .font(.caption2)
                            .lineLimit(1)
                    }
                    .foregroundColor(.secondary)
                }
            } else {
                Text("No upcoming events.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(hex: memberEvent.calendarColorHex).opacity(0.15))
        )
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter
    }()
}

private extension Color {
    init(hex: String) {
        let hexString = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int = UInt64()
        Scanner(string: hexString).scanHexInt64(&int)

        let r, g, b: UInt64
        switch hexString.count {
        case 6:
            (r, g, b) = ((int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        case 3:
            (r, g, b) = (((int >> 8) & 0xF) * 17, ((int >> 4) & 0xF) * 17, (int & 0xF) * 17)
        default:
            (r, g, b) = (0x00, 0x7A, 0xFF)
        }

        self.init(
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255
        )
    }
}
