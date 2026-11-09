//
//  NearbySession.swift  ·  OWNER: Person C (Rohan; took over from A)
//  Phone-to-phone connection for joining a hunt and racing, using MultipeerConnectivity
//  (Bluetooth + peer-to-peer Wi-Fi; no internet, no server).
//
//  Host:   startHosting(package:) → advertises a room code → sends .hunt to each player who connects
//  Player: join(code:)            → finds the host with that code → receives the hunt → waits for .start
//  Both:   send(_:) / race messages are forwarded to RaceSession.shared
//
//  Requires (already in Quarry/Info.plist): NSLocalNetworkUsageDescription and
//  NSBonjourServices = _quarry-hunt._tcp / _quarry-hunt._udp.
//

import Foundation
import MultipeerConnectivity
import Observation

@Observable
@MainActor
final class NearbySession {
    static let shared = NearbySession()

    enum Status: Equatable {
        case idle
        case hosting            // host: advertising, waiting for players
        case searching          // player: looking for a host with the code
        case connecting         // player: found the host, connecting
        case connected          // player: connected to the host
        case disconnected       // player: was connected, lost the host (race continues offline)
        case failed(String)     // player: user-facing error message
    }

    // MARK: Observable state
    private(set) var status: Status = .idle
    private(set) var roomCode: String?
    private(set) var isHosting = false
    /// Host: display names of players connected right now.
    private(set) var connectedPlayers: [String] = []
    /// Host: everyone who has joined and received the hunt during this hosting session.
    /// Players disconnect once they have the hunt, so this list is what the lobby shows.
    private(set) var joinedPlayers: [String] = []
    /// Player: name of the host we're connected to.
    private(set) var hostName: String?
    /// Player: the hunt the host sent us.
    private(set) var receivedHunt: HuntPackage?
    /// Player: when the host said to start (a few seconds in the future).
    private(set) var startAt: Date?
    /// Recent events, newest last. Shown on the debug screen so you can see what happened
    /// on a phone that isn't attached to Xcode.
    private(set) var log: [String] = []

    // MARK: Private
    static let serviceType = "quarry-hunt"   // must match NSBonjourServices in Info.plist
    @ObservationIgnored private let bridge = MultipeerBridge()
    @ObservationIgnored private var advertiser: MCNearbyServiceAdvertiser?
    @ObservationIgnored private var browser: MCNearbyServiceBrowser?
    @ObservationIgnored private var hostedPackage: HuntPackage?
    @ObservationIgnored private var raceStartedAt: Date?
    @ObservationIgnored private var joinTimeout: Task<Void, Never>?
    /// Automatic retries used for the current join (before the hunt has arrived).
    @ObservationIgnored private var retryCount = 0
    private static let maxRetries = 3
    @ObservationIgnored private var reconnectAttempts = 0
    @ObservationIgnored private var reconnectTask: Task<Void, Never>?

    init() {
        bridge.owner = self
        // Race updates go out over this connection.
        RaceSession.shared.sendHandler = { [weak self] message in self?.send(message) }
    }

    // MARK: - Host

    /// Starts advertising this hunt. Returns the 4-letter room code to show as text + QR.
    @discardableResult
    func startHosting(package: HuntPackage) -> String {
        stop()
        let code = RoomCode.make()
        let session = makeSession()

        let advertiser = MCNearbyServiceAdvertiser(
            peer: session.myPeerID,
            discoveryInfo: ["code": code],
            serviceType: Self.serviceType
        )
        advertiser.delegate = bridge
        advertiser.startAdvertisingPeer()

        self.advertiser = advertiser
        hostedPackage = package
        roomCode = code
        isHosting = true
        status = .hosting
        note("📡 Hosting \"\(package.title)\" with code \(code)")
        return code
    }

    /// Host: tell everyone to start at `date` (use a few seconds in the future so all phones start together).
    func startRace(at date: Date) {
        raceStartedAt = date
        send(.start(at: date))
    }

    // MARK: - Player

    /// Looks for a host advertising `code` and joins it.
    func join(code rawCode: String) {
        join(code: rawCode, isRetry: false)
    }

    private func join(code rawCode: String, isRetry: Bool) {
        let keptRetries = isRetry ? retryCount : 0
        stop()
        retryCount = keptRetries
        let code = rawCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let session = makeSession()
        bridge.targetCode = code

        let browser = MCNearbyServiceBrowser(peer: session.myPeerID, serviceType: Self.serviceType)
        browser.delegate = bridge
        browser.startBrowsingForPeers()

        self.browser = browser
        roomCode = code
        status = .searching
        note("🔎 Looking for a host with code \(code)")

        joinTimeout = Task { [weak self] in
            try? await Task.sleep(for: .seconds(20))
            guard let self, !Task.isCancelled else { return }
            if self.status == .searching || self.status == .connecting {
                self.browser?.stopBrowsingForPeers()
                self.status = .failed("No hunt found with code \(code). Check the code and stay close to the host's phone.")
            }
        }
    }

    // MARK: - Both

    /// Host → every connected player. Player → the host.
    func send(_ message: NearbyMessage) {
        guard let session = bridge.session, !session.connectedPeers.isEmpty else { return }
        do {
            try session.send(message.encoded(), toPeers: session.connectedPeers, with: .reliable)
        } catch {
            note("⚠️ Nearby send failed: \(error.localizedDescription)")
        }
    }

    /// Disconnects and resets everything (call when leaving the lobby / join screen without racing,
    /// or after the race is over).
    func stop() {
        joinTimeout?.cancel()
        joinTimeout = nil
        advertiser?.stopAdvertisingPeer()
        browser?.stopBrowsingForPeers()
        bridge.session?.disconnect()
        bridge.session = nil
        bridge.targetCode = nil
        advertiser = nil
        browser = nil
        hostedPackage = nil
        raceStartedAt = nil
        status = .idle
        roomCode = nil
        isHosting = false
        connectedPlayers = []
        joinedPlayers = []
        hostName = nil
        receivedHunt = nil
        startAt = nil
        retryCount = 0
        reconnectAttempts = 0
        reconnectTask?.cancel()
        reconnectTask = nil
    }

    // MARK: - Reconnect (player)

    private func scheduleReconnect(code: String) {
        guard reconnectAttempts < 5 else {
            note("⚠️ Gave up reconnecting. You can keep playing; the leaderboard won't update.")
            return
        }
        reconnectAttempts += 1
        let attempt = reconnectAttempts
        reconnectTask?.cancel()
        reconnectTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2))
            guard let self, !Task.isCancelled, self.status == .disconnected else { return }
            self.note("🔁 Reconnecting (try \(attempt) of 5)…")
            // Fresh session + search, keeping receivedHunt / startAt / roomCode.
            self.browser?.stopBrowsingForPeers()
            self.bridge.session?.disconnect()
            let session = self.makeSession()
            self.bridge.targetCode = code
            let browser = MCNearbyServiceBrowser(peer: session.myPeerID, serviceType: Self.serviceType)
            browser.delegate = self.bridge
            browser.startBrowsingForPeers()
            self.browser = browser
            // If this attempt doesn't connect within 15 s, try again.
            try? await Task.sleep(for: .seconds(15))
            guard !Task.isCancelled, self.status == .disconnected else { return }
            self.scheduleReconnect(code: code)
        }
    }

    // MARK: - Logging

    fileprivate func note(_ text: String) {
        print(text)
        let time = Date.now.formatted(date: .omitted, time: .standard)
        log.append("\(time)  \(text)")
        if log.count > 40 { log.removeFirst(log.count - 40) }
    }

    fileprivate func startFailed(_ what: String, _ error: any Error) {
        note("⚠️ Couldn't start \(what): \(error.localizedDescription)")
        if !isHosting {
            status = .failed("iOS blocked the search for nearby phones. Turn on Settings → Privacy & Security → Local Network → GooseChase, then try again.")
        }
    }

    // MARK: - Session setup

    /// One MCPeerID per phone (per display name), saved and reused. Apple recommends reusing
    /// peer IDs: a fresh ID with the same name on every attempt leaves "ghost" peers on the
    /// other phone, and new connections stall at "connecting".
    private func currentPeerID() -> MCPeerID {
        var name = PlayerIdentity.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if name.isEmpty { name = "Player" }
        while name.utf8.count > 60 { name.removeLast() }   // MCPeerID limit is 63 bytes

        let defaults = UserDefaults.standard
        if let data = defaults.data(forKey: "nearbyPeerID"),
           let saved = try? NSKeyedUnarchiver.unarchivedObject(ofClass: MCPeerID.self, from: data),
           saved.displayName == name {
            return saved
        }
        let peer = MCPeerID(displayName: name)
        if let data = try? NSKeyedArchiver.archivedData(withRootObject: peer, requiringSecureCoding: true) {
            defaults.set(data, forKey: "nearbyPeerID")
        }
        return peer
    }

    private func makeSession() -> MCSession {
        let peer = currentPeerID()
        // .none: .required often connects and then drops a few seconds later (certificate handshake).
        // Hunts aren't sensitive and this only travels between phones in the same room.
        let session = MCSession(peer: peer, securityIdentity: nil, encryptionPreference: .none)
        session.delegate = bridge
        bridge.session = session
        return session
    }

    // MARK: - Events from the bridge (always on the main actor)

    fileprivate func peerConnected(_ peer: MCPeerID) {
        if isHosting {
            if !connectedPlayers.contains(peer.displayName) {
                connectedPlayers.append(peer.displayName)
            }
            if !joinedPlayers.contains(peer.displayName) {
                joinedPlayers.append(peer.displayName)
            }
            note("✅ \(peer.displayName) joined")
            guard let session = bridge.session else { return }
            // Send the hunt (and the start time, if the race already started) to this player only.
            var messages: [NearbyMessage] = []
            if let hostedPackage { messages.append(.hunt(hostedPackage)) }
            if let raceStartedAt { messages.append(.start(at: raceStartedAt)) }
            for message in messages {
                do { try session.send(message.encoded(), toPeers: [peer], with: .reliable) }
                catch { note("⚠️ Sending to \(peer.displayName) failed: \(error.localizedDescription)") }
            }
        } else {
            joinTimeout?.cancel()
            reconnectAttempts = 0
            reconnectTask?.cancel()
            // Stopping the search right away can drop a connection that's still settling,
            // so stop it a few seconds later.
            Task { [weak self] in
                try? await Task.sleep(for: .seconds(5))
                guard let self, self.status == .connected else { return }
                self.browser?.stopBrowsingForPeers()
            }
            hostName = peer.displayName
            status = .connected
            note("✅ Connected to host \(peer.displayName)")
            send(.hello(player: PlayerProgress(
                id: PlayerIdentity.id, name: PlayerIdentity.name, cleared: 0,
                total: receivedHunt?.checkpoints.count ?? 0, finishedAt: nil, updatedAt: .now
            )))
        }
    }

    fileprivate func peerDisconnected(_ peer: MCPeerID) {
        if isHosting {
            connectedPlayers.removeAll { $0 == peer.displayName }
            note("👋 \(peer.displayName) left")
        } else if receivedHunt == nil, let code = roomCode, retryCount < Self.maxRetries {
            // Dropped before the hunt arrived: try again automatically, with a short pause.
            retryCount += 1
            let attempt = retryCount
            note("🔁 Dropped before the hunt arrived, retrying (\(attempt) of \(Self.maxRetries))…")
            status = .connecting
            let retryCode = code
            Task { [weak self] in
                try? await Task.sleep(for: .seconds(Double(attempt)))
                self?.join(code: retryCode, isRetry: true)
            }
        } else if receivedHunt != nil, let code = roomCode {
            // Already have the hunt: keep it (and any start time) and quietly reconnect
            // so the leaderboard keeps working. The player can keep playing meanwhile.
            status = .disconnected
            note("⚠️ Lost connection to the host, reconnecting…")
            scheduleReconnect(code: code)
        } else if status == .connected || status == .connecting {
            status = .failed("Lost connection to the host. Tap Join to try again.")
            note("⚠️ Lost connection to the host")
        }
    }

    fileprivate func peerConnecting() {
        if !isHosting, status == .searching { status = .connecting }
    }

    fileprivate func received(_ data: Data) {
        let message: NearbyMessage
        do { message = try NearbyMessage.decode(data) }
        catch { note("⚠️ Couldn't decode a message: \(error.localizedDescription)"); return }

        switch message {
        case .hunt(let package):
            receivedHunt = package
            note("📦 Received hunt \"\(package.title)\" (\(package.checkpoints.count) checkpoints)")
        case .start(let date):
            startAt = date
            note("🏁 Race starts at \(date)")
        case .hello, .progress, .leaderboard:
            RaceSession.shared.receive(message)
        }
    }
}

// MARK: - MultipeerConnectivity delegates
// MultipeerConnectivity calls these on its own background queues. The bridge does the
// minimum work there and hops to the main actor for anything that touches state.

nonisolated final class MultipeerBridge: NSObject, @unchecked Sendable,
                                         MCSessionDelegate,
                                         MCNearbyServiceAdvertiserDelegate,
                                         MCNearbyServiceBrowserDelegate {
    weak var owner: NearbySession?
    var session: MCSession?
    var targetCode: String?

    // MCSessionDelegate
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        guard session === self.session else { return }   // ignore callbacks from an old session
        let name = peerID.displayName
        let label: String
        switch state {
        case .connected: label = "connected"
        case .connecting: label = "connecting"
        case .notConnected: label = "not connected"
        @unknown default: label = "unknown"
        }
        Task { @MainActor [weak owner = self.owner] in owner?.note("↔️ \(name): \(label)") }
        Task { @MainActor [weak owner = self.owner] in
            switch state {
            case .connected: owner?.peerConnected(peerID)
            case .notConnected: owner?.peerDisconnected(peerID)
            case .connecting: owner?.peerConnecting()
            @unknown default: break
            }
        }
    }

    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        guard session === self.session else { return }
        Task { @MainActor [weak owner = self.owner] in owner?.received(data) }
    }

    func session(_ session: MCSession, didReceiveCertificate certificate: [Any]?, fromPeer peerID: MCPeerID,
                 certificateHandler: @escaping (Bool) -> Void) {
        certificateHandler(true)   // always accept: no encryption, same-room phones
    }

    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: (any Error)?) {}

    // MCNearbyServiceAdvertiserDelegate (host)
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID,
                    withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        // Players only invite the host whose room code they typed or scanned, so accept.
        let name = peerID.displayName
        Task { @MainActor [weak owner = self.owner] in owner?.note("📨 \(name) asked to join, accepting") }
        invitationHandler(true, session)
    }

    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: any Error) {
        Task { @MainActor [weak owner = self.owner] in owner?.startFailed("hosting", error) }
    }

    // MCNearbyServiceBrowserDelegate (player)
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        let theirCode = info?["code"] ?? "?"
        let name = peerID.displayName
        Task { @MainActor [weak owner = self.owner] in owner?.note("👀 Saw \(name) hosting code \(theirCode)") }
        guard let session, let targetCode, theirCode.uppercased() == targetCode else { return }
        Task { @MainActor [weak owner = self.owner] in owner?.note("🔗 Code matches, inviting \(name)") }
        browser.invitePeer(peerID, to: session, withContext: nil, timeout: 30)
        Task { @MainActor [weak owner = self.owner] in owner?.peerConnecting() }
    }

    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {}

    func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: any Error) {
        Task { @MainActor [weak owner = self.owner] in owner?.startFailed("searching", error) }
    }
}
