//
//  Work_Order_Inspection_AppApp.swift
//  Work Order Inspection App
//
//  Created by Tyler Greenwaldt on 5/20/26.
//

import SwiftUI
import SwiftData

@main
struct Work_Order_Inspection_AppApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
