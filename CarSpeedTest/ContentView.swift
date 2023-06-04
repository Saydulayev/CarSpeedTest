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
    @State private var isShowingShareSheet = false
    
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
                              form: CGSize(width: UIScreen.main.bounds.width - 15, height: 240))
                .padding(.horizontal, 10)
                
                .padding(30)
                HStack {
                    Button(action: {
                        locationManager.startUpdatingLocation()
                        locationManager.resetMeasurement()
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
            
            VStack {
                HStack {
                    Spacer()
                    Button(action: {
                        isShowingShareSheet = true
                    }) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.title)
                            .foregroundColor(.primary)
                    }
                    .padding(.trailing)
                    
                    Button(action: {
                        historyStore.clearAccelerationData()
                    }) {
                        Image(systemName: "trash")
                            .font(.title)
                            .foregroundColor(.primary)
                    }
                    .padding(.trailing)
                }
                
                VStack {
                    List(historyStore.accelerationData) { data in
                        VStack(alignment: .leading) {
                            Text("Acceleration: \(data.acceleration, specifier: "%.\(displayPrecision)f") \(currentSpeedUnit)")
                            Text("Timestamp: \(data.timestampString)")
                        }
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
            locationManager.requestLocationAuthorization()
            locationManager.updateInterval = measurementInterval
        }
        
        .onReceive(locationManager.$averageSpeed) { _ in
            DispatchQueue.main.async {
                let acceleration = locationManager.acceleration
                let timestamp = Date()
                let newData = AccelerationData(acceleration: acceleration, timestamp: timestamp)
                historyStore.accelerationData.append(newData)
                accelerationData = historyStore.accelerationData
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
        .sheet(isPresented: $isShowingShareSheet) {
            ShareSheet(activityItems: [exportAccelerationData()])
        }
    }
    
    func exportAccelerationData() -> URL {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try! encoder.encode(historyStore.accelerationData)
        
        let fileManager = FileManager.default
        let documentDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileURL = documentDirectory.appendingPathComponent("acceleration_data.json")
        
        do {
            try data.write(to: fileURL)
            return fileURL
        } catch {
            fatalError("Failed to write acceleration data to file: \(error.localizedDescription)")
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
    
    func clearAccelerationData() {
        accelerationData.removeAll()
    }
}

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    @Published var acceleration: Double = 0.0
    @Published var averageSpeed: CLLocationSpeed = 0.0
    var updateInterval: Double = 1.0
    
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
    
    func resetMeasurement() {
        acceleration = 0.0
        averageSpeed = 0.0
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let lastLocation = locations.last else { return }
        
        let currentSpeed = lastLocation.speed
        let acceleration = calculateAcceleration(from: currentSpeed)
        
        averageSpeed = currentSpeed
        self.acceleration = acceleration
    }
    
    private func calculateAcceleration(from speed: CLLocationSpeed) -> Double {
        let initialSpeed = 0.0
        let targetSpeeds = [100.0, 200.0] // Скорости, до которых вы хотите измерить ускорение
        let timeInterval = 10.0 // Временной интервал, в течение которого происходит измерение ускорения
        
        if speed >= initialSpeed && speed <= targetSpeeds[0] {
            // Измерение ускорения от 0 до 100 км/ч
            return (speed - initialSpeed) / timeInterval
        } else if speed > targetSpeeds[0] && speed <= targetSpeeds[1] {
            // Измерение ускорения от 100 до 200 км/ч
            let accelerationRange = targetSpeeds[0] - initialSpeed
            let timeRange = timeInterval / 2.0
            return accelerationRange / timeRange
        } else {
            return 0.0
        }
    }
    
    func requestLocationAuthorization() {
        locationManager.requestWhenInUseAuthorization()
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        let historyStore = HistoryStore(accelerationData: []) // Pass an empty array as the argument
        
        historyStore.accelerationData = [
            AccelerationData(acceleration: 2.5, timestamp: Date()),
            AccelerationData(acceleration: 3.2, timestamp: Date()),
            AccelerationData(acceleration: 1.8, timestamp: Date())
        ]
        
        return ContentView().environmentObject(historyStore)
    }
}






//struct ContentView_Previews: PreviewProvider {
//    static var previews: some View {
//        ContentView()
//            .environmentObject(HistoryStore())
//    }
//}

