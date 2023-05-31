//
//  ContentView.swift
//  CarSpeedTest
//
//  Created by Dokx Dig on 30.05.23.
//

import SwiftUI
import CoreLocation
import SwiftUICharts

struct ContentView: View {
    @EnvironmentObject var historyStore: HistoryStore // Use the injected HistoryStore

    @Environment(\.colorScheme) var colorScheme
    @StateObject private var locationManager = LocationManager()
    @State private var accelerationData: [AccelerationData] = []
    @AppStorage("SelectedUnitIndex") private var selectedUnitIndex = 0 // Use AppStorage to observe and store the selected unit index
    @State private var measurementInterval = UserDefaults.standard.double(forKey: "MeasurementInterval")
    @State private var displayPrecision = UserDefaults.standard.integer(forKey: "DisplayPrecision")
    
    private let speedUnits: [String] = ["m/s", "km/h", "mph"]
    
    var currentSpeedUnit: String {
        speedUnits[selectedUnitIndex]
    }
    
    
    var body: some View {
        TabView {
            VStack {
                        Text("Acceleration: \(locationManager.acceleration, specifier: "%.\(displayPrecision)f") \(currentSpeedUnit)") // Use currentSpeedUnit to display the current speed unit
                            .font(.title)
                            .padding()
                        
                        LineChartView(data: accelerationData.map(\.acceleration), title: "Acceleration Speed")
                            .padding()
                
                HStack {
                    Button(action: {
                        locationManager.startUpdatingLocation()
                        locationManager.resetMeasurement()
                    }) {
                        Text("Start")
                            .font(.title)
                            .padding()
                            .background(LinearGradient(gradient: Gradient(colors: [Color.black, Color.blue]), startPoint: .bottom, endPoint: .top))
                            .foregroundColor(.white)
                            .cornerRadius(10)
                            .shadow(color: colorScheme == .dark ? Color.white.opacity(0.3) : Color.black.opacity(0.3), radius: 3, x: 0, y: 0)
                    }
                    
                    Button(action: {
                        locationManager.stopUpdatingLocation()
                    }) {
                        Text("Stop")
                            .font(.title)
                            .padding()
                            .background(LinearGradient(gradient: Gradient(colors: [Color.black, Color.red]), startPoint: .bottom, endPoint: .top))
                            .foregroundColor(.white)
                            .cornerRadius(10)
                            .shadow(color: colorScheme == .dark ? Color.white.opacity(0.3) : Color.black.opacity(0.3), radius: 3, x: 0, y: 0)
                    }
                }
                .padding(.horizontal)
            }
            .tabItem {
                Image(systemName: "speedometer")
                Text("Speed")
            }
            
            VStack {
                List(historyStore.accelerationData) { data in
                    VStack(alignment: .leading) {
                        Text("Acceleration: \(data.acceleration, specifier: "%.\(displayPrecision)f") m/s²")
                        Text("Timestamp: \(data.timestampString)")
                    }
                }
            }
            .tabItem {
                Image(systemName: "clock")
                Text("History")
            }
            
            Form {
                Section(header: Text("Measurement Interval")) {
                    Slider(value: $measurementInterval, in: 0...5, step: 0.1) {
                        Text("Interval: \(measurementInterval, specifier: "%.1f") seconds")
                    }
                }
                
                Section(header: Text("Display Precision")) {
                    Stepper(value: $displayPrecision, in: 0...2) {
                        Text("Precision: \(displayPrecision)")
                    }
                }
                
                Section(header: Text("Preferred Unit")) {
                    Picker("Unit", selection: $selectedUnitIndex) {
                        ForEach(0..<speedUnits.count, id: \.self) { index in
                            Text(speedUnits[index])
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
            }
            .tabItem {
                Image(systemName: "gear")
                Text("Settings")
            }
        }
        .onAppear {
            locationManager.updateInterval = measurementInterval
        }
        .onReceive(locationManager.$averageSpeed) { _ in
            DispatchQueue.main.async {
                let acceleration = locationManager.acceleration
                let timestamp = Date()
                let newData = AccelerationData(acceleration: acceleration, timestamp: timestamp)
                historyStore.accelerationData.append(newData)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
            locationManager.stopUpdatingLocation()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            if locationManager.acceleration != 0.0 {
                locationManager.startUpdatingLocation()
            }
        }
        .onChange(of: measurementInterval) { newValue in
            locationManager.updateInterval = newValue
            UserDefaults.standard.set(newValue, forKey: "MeasurementInterval")
        }
        .onChange(of: selectedUnitIndex) { newValue in
            UserDefaults.standard.set(newValue, forKey: "SelectedUnitIndex")
        }
        .onChange(of: displayPrecision) { newValue in
            UserDefaults.standard.set(newValue, forKey: "DisplayPrecision")
        }
    }
}

struct AccelerationData: Identifiable, Codable, Equatable {
    var id = UUID()
    let acceleration: Double
    let timestamp: Date
    
    var timestampString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, HH:mm:ss"
        return formatter.string(from: timestamp)
    }
    
    static func == (lhs: AccelerationData, rhs: AccelerationData) -> Bool {
        return lhs.id == rhs.id
    }
}

class HistoryStore: ObservableObject {
    @Published var accelerationData: [AccelerationData]
    
    init(accelerationData: [AccelerationData]) {
        self.accelerationData = accelerationData
    }
}


class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    @Published var acceleration: Double = 0.0
    @Published var averageSpeed: CLLocationSpeed = 0.0
    var updateInterval: Double = 1.0
    
    private var previousSpeed: CLLocationSpeed?
    private var previousTimestamp: Date?
    private var totalDistance: CLLocationDistance = 0.0
    private var startTime: Date?
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
    }
    
    func startUpdatingLocation() {
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
        locationManager.pausesLocationUpdatesAutomatically = false
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.activityType = .automotiveNavigation
        locationManager.distanceFilter = kCLDistanceFilterNone
        locationManager.delegate = self
        locationManager.startUpdatingLocation()
        locationManager.startMonitoringSignificantLocationChanges()
        locationManager.showsBackgroundLocationIndicator = true
    }
    
    func stopUpdatingLocation() {
        locationManager.stopUpdatingLocation()
        locationManager.showsBackgroundLocationIndicator = false
    }
    
    func resetMeasurement() {
        totalDistance = 0.0
        startTime = Date()
        acceleration = 0.0
        averageSpeed = 0.0
        previousSpeed = nil
        previousTimestamp = nil
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        let currentSpeed = location.speed
        let currentTimestamp = location.timestamp
        
        if let previousSpeed = previousSpeed,
           let previousTimestamp = previousTimestamp,
           currentSpeed > 0.0,
           currentTimestamp > previousTimestamp {
            let timeDifference = currentTimestamp.timeIntervalSince(previousTimestamp)
            let acceleration = (currentSpeed - previousSpeed) / timeDifference
            self.acceleration = acceleration
        }
        
        if let startTime = startTime {
            let distance = location.distance(from: locations[0])
            totalDistance += distance
            
            let elapsedTime = currentTimestamp.timeIntervalSince(startTime)
            let averageSpeed = totalDistance / elapsedTime
            self.averageSpeed = averageSpeed
        }
        
        previousSpeed = currentSpeed
        previousTimestamp = currentTimestamp
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(HistoryStore(accelerationData: [
                AccelerationData(acceleration: 2.5, timestamp: Date()),
                AccelerationData(acceleration: 3.2, timestamp: Date().addingTimeInterval(-10)),
                AccelerationData(acceleration: 1.8, timestamp: Date().addingTimeInterval(-20))
            ]))
    }
}






