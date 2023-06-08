//
//  CarSpeedTestApp.swift
//  CarSpeedTest
//
//  Created by Akhmed on 30.05.23.
//

import SwiftUI
import Firebase
import FirebaseCore
import FirebaseDatabase

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
        return true
    }
}

@main
struct CarSpeedTestApp: App {
    init() {
        FirebaseApp.configure() // Configure Firebase only once in the initializer
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}




//@main
//struct AccelerationApp: App {
//    @StateObject private var historyStore = HistoryStore(accelerationData: [])
//   
//    var body: some Scene {
//        WindowGroup {
//            ContentView()
//                .environmentObject(historyStore)
//        }
//    }
//}


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







