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
            ContentView()
                #if DEBUG
                .overlay(alignment: .bottomLeading) { NearbyDebugButton() }   // temporary: N2 test
                #endif
        }
        .modelContainer(sharedModelContainer)
    }
}
