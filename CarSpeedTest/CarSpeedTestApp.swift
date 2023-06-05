//
//  CarSpeedTestApp.swift
//  CarSpeedTest
//
//  Created by Akhmed on 30.05.23.
//

import SwiftUI
import CoreLocation
import Firebase


@main
struct AccelerationApp: App {
    @StateObject private var historyStore = HistoryStore(accelerationData: [])
    init() {
            FirebaseApp.configure() // Configure Firebase here
        }
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


//@main
//struct YourApp: App {
//  // register app delegate for Firebase setup
//  @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
//
//
//  var body: some Scene {
//    WindowGroup {
//      NavigationView {
//        ContentView()
//      }
//    }
//  }
//}







