//
//  QuarryApp.swift
//  Quarry
//

import SwiftUI
import SwiftData

@main
struct QuarryApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([Hunt.self, Checkpoint.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(sharedModelContainer)
    }
}

/// Wraps ContentView with app-wide handling of join links:
/// scanning the host's QR with the iPhone Camera app opens quarry://join?code=XXXX,
/// which shows the Join screen with the code already filled in.
private struct RootView: View {
    @State private var pendingJoin: PendingJoin?

    var body: some View {
        ContentView()
            .onOpenURL { url in
                if let code = RoomCode.code(from: url) {
                    pendingJoin = PendingJoin(code: code)
                }
            }
            .sheet(item: $pendingJoin) { join in
                JoinView(initialCode: join.code)
            }
            #if DEBUG
            .overlay(alignment: .bottomLeading) { NearbyDebugButton() }   // temporary test screen
            #endif
    }
}

private struct PendingJoin: Identifiable {
    let code: String
    var id: String { code }
}
