//
//  CarSpeedTestApp.swift
//  CarSpeedTest
//
//  Created by Dokx Dig on 30.05.23.
//

import SwiftUI
import CoreLocation

@main
struct CarSpeedTestApp: App {
    let historyStore = HistoryStore(accelerationData: []) // Initialize the HistoryStore

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(historyStore) // Inject the HistoryStore as an environment object
        }
    }
}

//@main
//struct CarSpeedTestApp: App {
//    var body: some Scene {
//        WindowGroup {
//            ContentView()
//        }
//    }
//}


//@MainActor
//class SettingsManager: ObservableObject {
//    @Published var settings = Settings()
//}
//
//@main
//struct CarSpeedTestApp: App {
//    @StateObject private var settingsManager = SettingsManager()
//
//    var body: some Scene {
//        WindowGroup {
//            ContentView()
//                .environmentObject(settingsManager)
//        }
//    }
//}







