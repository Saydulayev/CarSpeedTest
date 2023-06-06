//
//  ContentView.swift
//  CarSpeedTest
//
//  Created by Akhmed on 30.05.23.
//

import SwiftUI
import CoreLocation
import CoreMotion
import SwiftUICharts
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore
import FirebaseAnalytics


struct ContentView: View {
    @Environment(\.colorScheme) var colorScheme
    @StateObject private var locationManager = LocationManager()
    @State private var accelerationData: [AccelerationData] = []
    @AppStorage("SelectedUnitIndex") private var selectedUnitIndex = 0 // Use AppStorage to observe and store the selected unit index
    @State private var measurementInterval = UserDefaults.standard.double(forKey: "MeasurementInterval")
    @State private var displayPrecision = UserDefaults.standard.integer(forKey: "DisplayPrecision")
    
    private let speedUnits: [String] = ["km/h", "mph"]
    
    var currentSpeedUnit: String {
        speedUnits[selectedUnitIndex]
    }
    
    var body: some View {
        TabView {
            VStack {
                Text("Acceleration: \(locationManager.acceleration, specifier: "%.\(displayPrecision)f") \(currentSpeedUnit)") // Use currentSpeedUnit to display the current speed unit
                    .font(.title)
                    .padding()
                
                LineChartView(data: accelerationData.map(\.acceleration),
                              title: "Acceleration Speed",
                              legend: "Acceleration",
                              style: ChartStyle(backgroundColor: Color.white,
                                                accentColor: Color.blue,
                                                gradientColor: GradientColor(start: Color.blue, end: Color.white),
                                                textColor: Color.black,
                                                legendTextColor: Color.gray,
                                                dropShadowColor: Color.gray),
                              form: CGSize(width: UIScreen.main.bounds.width - 20, height: 240))
                    .padding(.horizontal, 10)
                
                .padding(30)
                HStack {
                    Button(action: {
                        locationManager.startUpdatingLocation()
                        locationManager.startUpdatingMotion()
                    }) {
                        Text("Start")
                            .font(.title)
                            .padding()
                            .foregroundColor(colorScheme == .dark ? Color.white : Color.black)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(colorScheme == .dark ? Color.black : Color.white)
                                    .shadow(color: colorScheme == .dark ? Color.white.opacity(0.3) : Color.black.opacity(0.3), radius: 3, x: 0, y: 0)
                            )
                    }
                    
                    Button(action: {
                        locationManager.stopUpdatingLocation()
                        locationManager.stopUpdatingMotion()
                    }) {
                        Text("Stop")
                            .font(.title)
                            .padding()
                            .foregroundColor(colorScheme == .dark ? Color.white : Color.black)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(colorScheme == .dark ? Color.black : Color.white)
                                    .shadow(color: colorScheme == .dark ? Color.white.opacity(0.3) : Color.black.opacity(0.3), radius: 3, x: 0, y: 0)
                            )
                    }
                }
                .padding(.horizontal)
            }
            .tabItem {
                Image(systemName: "speedometer")
                Text("Speed")
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
            locationManager.requestLocationAuthorization()
            locationManager.updateInterval = measurementInterval
        }
        
        .onReceive(locationManager.$averageSpeed) { _ in
            DispatchQueue.main.async {
                let acceleration = locationManager.acceleration
                let timestamp = Date()
                let newData = AccelerationData(acceleration: acceleration, timestamp: timestamp)
                accelerationData.append(newData)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
            locationManager.stopUpdatingLocation()
            locationManager.stopUpdatingMotion()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            if locationManager.acceleration != 0.0 {
                locationManager.startUpdatingLocation()
                locationManager.startUpdatingMotion()
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

struct AccelerationData: Identifiable {
    var id = UUID()
    let acceleration: Double
    let timestamp: Date
    
    var timestampString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, HH:mm:ss"
        return formatter.string(from: timestamp)
    }
}

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    @Published var acceleration: Double = 0.0
    @Published var averageSpeed: CLLocationSpeed = 0.0
    var updateInterval: Double = 1.0
    private var motionManager: CMMotionManager?
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.pausesLocationUpdatesAutomatically = false
    }
    
    func startUpdatingLocation() {
        locationManager.startUpdatingLocation()
        acceleration = 0.0
    }
    
    func stopUpdatingLocation() {
        locationManager.stopUpdatingLocation()
    }
    
    func startUpdatingMotion() {
        motionManager = CMMotionManager()
        motionManager?.accelerometerUpdateInterval = updateInterval
        
        guard let motionManager = motionManager else { return }
        
        motionManager.startAccelerometerUpdates(to: .main) { [weak self] (data, error) in
            guard let accelerationData = data?.acceleration else { return }
            
            let acceleration = sqrt(pow(accelerationData.x, 2) + pow(accelerationData.y, 2) + pow(accelerationData.z, 2))
            self?.acceleration = acceleration
        }
    }
    
    func stopUpdatingMotion() {
        motionManager?.stopAccelerometerUpdates()
        motionManager = nil
    }
    
    func resetMeasurement() {
        acceleration = 0.0
        averageSpeed = 0.0
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let lastLocation = locations.last else { return }
        
        let currentSpeed = lastLocation.speed
        averageSpeed = currentSpeed >= 0 ? currentSpeed : averageSpeed
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if manager.authorizationStatus == .authorizedAlways ||
            manager.authorizationStatus == .authorizedWhenInUse {
            startUpdatingLocation()
        }
    }
    
    func requestLocationAuthorization() {
        locationManager.requestWhenInUseAuthorization()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}



