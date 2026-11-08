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
    /// Host: display names of connected players.
    private(set) var connectedPlayers: [String] = []
    /// Player: name of the host we're connected to.
    private(set) var hostName: String?
    /// Player: the hunt the host sent us.
    private(set) var receivedHunt: HuntPackage?
    /// Player: when the host said to start (a few seconds in the future).
    private(set) var startAt: Date?

    // MARK: Private
    static let serviceType = "quarry-hunt"   // must match NSBonjourServices in Info.plist
    @ObservationIgnored private let bridge = MultipeerBridge()
    @ObservationIgnored private var advertiser: MCNearbyServiceAdvertiser?
    @ObservationIgnored private var browser: MCNearbyServiceBrowser?
    @ObservationIgnored private var hostedPackage: HuntPackage?
    @ObservationIgnored private var raceStartedAt: Date?
    @ObservationIgnored private var joinTimeout: Task<Void, Never>?

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
        print("📡 Hosting \"\(package.title)\" with code \(code)")
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
        stop()
        let code = rawCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let session = makeSession()
        bridge.targetCode = code

        let browser = MCNearbyServiceBrowser(peer: session.myPeerID, serviceType: Self.serviceType)
        browser.delegate = bridge
        browser.startBrowsingForPeers()

        self.browser = browser
        roomCode = code
        status = .searching
        print("🔎 Looking for a host with code \(code)")

        joinTimeout = Task { [weak self] in
            try? await Task.sleep(for: .seconds(12))
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
            print("⚠️ Nearby send failed:", error)
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
        hostName = nil
        receivedHunt = nil
        startAt = nil
    }

    // MARK: - Session setup

    private func makeSession() -> MCSession {
        var name = PlayerIdentity.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if name.isEmpty { name = "Player" }
        // MCPeerID display names are limited to 63 bytes.
        while name.utf8.count > 60 { name.removeLast() }
        let peer = MCPeerID(displayName: name)
        let session = MCSession(peer: peer, securityIdentity: nil, encryptionPreference: .required)
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
            print("✅ \(peer.displayName) joined")
            guard let session = bridge.session else { return }
            // Send the hunt (and the start time, if the race already started) to this player only.
            var messages: [NearbyMessage] = []
            if let hostedPackage { messages.append(.hunt(hostedPackage)) }
            if let raceStartedAt { messages.append(.start(at: raceStartedAt)) }
            for message in messages {
                do { try session.send(message.encoded(), toPeers: [peer], with: .reliable) }
                catch { print("⚠️ Sending to \(peer.displayName) failed:", error) }
            }
        } else {
            joinTimeout?.cancel()
            browser?.stopBrowsingForPeers()
            hostName = peer.displayName
            status = .connected
            print("✅ Connected to host \(peer.displayName)")
            send(.hello(player: PlayerProgress(
                id: PlayerIdentity.id, name: PlayerIdentity.name, cleared: 0,
                total: receivedHunt?.checkpoints.count ?? 0, finishedAt: nil, updatedAt: .now
            )))
        }
    }

    fileprivate func peerDisconnected(_ peer: MCPeerID) {
        if isHosting {
            connectedPlayers.removeAll { $0 == peer.displayName }
            print("👋 \(peer.displayName) left")
        } else if status == .connected {
            // Keep the hunt and any start time: the player can keep playing offline.
            status = .disconnected
            print("⚠️ Lost connection to the host")
        }
    }

    fileprivate func peerConnecting() {
        if !isHosting, status == .searching { status = .connecting }
    }

    fileprivate func received(_ data: Data) {
        let message: NearbyMessage
        do { message = try NearbyMessage.decode(data) }
        catch { print("⚠️ Couldn't decode nearby message:", error); return }

        switch message {
        case .hunt(let package):
            receivedHunt = package
            print("📦 Received hunt \"\(package.title)\" (\(package.checkpoints.count) checkpoints)")
        case .start(let date):
            startAt = date
            print("🏁 Race starts at \(date)")
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
        Task { @MainActor [weak owner = self.owner] in owner?.received(data) }
    }

    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: (any Error)?) {}

    // MCNearbyServiceAdvertiserDelegate (host)
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID,
                    withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        // Players only invite the host whose room code they typed or scanned, so accept.
        invitationHandler(true, session)
    }

    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: any Error) {
        print("⚠️ Couldn't start hosting:", error)
    }

    // MCNearbyServiceBrowserDelegate (player)
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        guard let session, let targetCode, info?["code"]?.uppercased() == targetCode else { return }
        print("🔗 Found host \(peerID.displayName) for code \(targetCode), inviting")
        browser.invitePeer(peerID, to: session, withContext: nil, timeout: 15)
        Task { @MainActor [weak owner = self.owner] in owner?.peerConnecting() }
    }

    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {}

    func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: any Error) {
        print("⚠️ Couldn't start searching:", error)
    }
}
