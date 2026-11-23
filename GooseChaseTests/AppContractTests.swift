//
//  AppContractTests.swift  ·  GooseChaseTests
//  Guards the values that must survive the Quarry → GooseChase rename: the quarry:// URL scheme,
//  the Bonjour service type, and PlayerIdentity's stable ID.
//  Needs a HOSTED test target (Host Application = Quarry, the default for an app's unit test
//  bundle) so Bundle.main is the app and its Info.plist is readable.
//

import Foundation
import Testing
@testable import Quarry

@MainActor
@Suite("App contracts (keep through the rename)")
struct AppContractTests {

    @Test("Info.plist registers the quarry:// URL scheme")
    func urlScheme() throws {
        let types = try #require(Bundle.main.object(forInfoDictionaryKey: "CFBundleURLTypes") as? [[String: Any]],
                                 "Is the test target hosted in the Quarry app?")
        let schemes = types.flatMap { $0["CFBundleURLSchemes"] as? [String] ?? [] }
        #expect(schemes.contains("quarry"))
    }

    @Test("Bonjour services in Info.plist match NearbySession.serviceType")
    func bonjourServices() throws {
        let services = try #require(Bundle.main.object(forInfoDictionaryKey: "NSBonjourServices") as? [String])
        let type = NearbySession.serviceType
        #expect(type == "quarry-hunt")
        #expect(services.contains("_\(type)._tcp"))
        #expect(services.contains("_\(type)._udp"))
    }

    @Test("PlayerIdentity.id is a UUID and stable across reads")
    func playerID() {
        // Side effect: creates the "playerID" UserDefaults key in the test host if it's missing,
        // exactly as the app does on first use. Nothing else is written.
        let first = PlayerIdentity.id
        let second = PlayerIdentity.id
        #expect(first == second)
        #expect(UUID(uuidString: first) != nil)
    }
}
