//
//  CarSpeedTestApp.swift
//  CarSpeedTest
//
//  Created by Dokx Dig on 30.05.23.
//

import SwiftUI
import CoreLocation

@main
struct AccelerationApp: App {
    @StateObject private var historyStore = HistoryStore(accelerationData: [])
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(historyStore)
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







