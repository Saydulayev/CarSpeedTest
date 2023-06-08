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
import Firebase
import FirebaseAuth
import FirebaseDatabase


struct ContentView: View {
    @Environment(\.colorScheme) var colorScheme
    @StateObject private var locationManager = LocationManager()
    @State private var accelerationData: [AccelerationData] = []
    @AppStorage("SelectedUnitIndex") private var selectedUnitIndex = 0
    @State private var measurementInterval = UserDefaults.standard.double(forKey: "MeasurementInterval")
    @State private var displayPrecision = UserDefaults.standard.integer(forKey: "DisplayPrecision")
    
    @State private var timeTo100: TimeInterval = 0.0
    @State private var timeTo200: TimeInterval = 0.0
    
    private let speedUnits: [String] = ["km/h", "mph"]
    
    var currentSpeedUnit: String {
        speedUnits[selectedUnitIndex]
    }
    
    var body: some View {
        TabView {
            VStack {
                if Auth.auth().currentUser != nil {
                    Text("Time to 100 km/h: \(timeTo100, specifier: "%.1f") seconds")
                    Text("Time to 200 km/h: \(timeTo200, specifier: "%.1f") seconds")
                    Text("Acceleration: \(locationManager.acceleration, specifier: "%.\(displayPrecision)f") \(currentSpeedUnit)") // Use currentSpeedUnit to display the current speed unit
                        .font(.title)
                        .padding()
                } else {
                    Text("Please sign in to view the data")
                }
                
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
            
            AuthView()
                            .tabItem {
                                Image(systemName: "person.fill")
                                Text("Account")
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
                
                Section(header: Text("Time to Reach Speed")) {
                    Text("Time to 100 km/h: \(timeTo100, specifier: "%.1f") seconds")
                    Text("Time to 200 km/h: \(timeTo200, specifier: "%.1f") seconds")
                }
            }
            .tabItem {
                Image(systemName: "gear")
                Text("Settings")
            }
        }
        .onAppear {
            setupFirebase()
            locationManager.requestLocationAuthorization()
            locationManager.updateInterval = measurementInterval
        }
        .onReceive(locationManager.$averageSpeed) { averageSpeed in
            DispatchQueue.main.async {
                let timestamp = Date()
                
                if timeTo100 == 0.0 && averageSpeed >= 100.0 {
                    timeTo100 = timestamp.timeIntervalSince(accelerationData.first?.timestamp ?? timestamp)
                }
                
                if timeTo200 == 0.0 && averageSpeed >= 200.0 {
                    timeTo200 = timestamp.timeIntervalSince(accelerationData.first?.timestamp ?? timestamp)
                }
                
                saveAccelerationData(acceleration: averageSpeed, timestamp: timestamp)
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
    
    func setupFirebase() {
            if FirebaseApp.app() == nil {
                FirebaseApp.configure()
            }
        }
    
    func saveAccelerationData(acceleration: Double, timestamp: Date) {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        let database = Database.database().reference()
        let userAccelerationRef = database.child("acceleration").child(userId).childByAutoId()
        
        let data: [String: Any] = [
            "acceleration": acceleration,
            "timestamp": timestamp.timeIntervalSince1970
        ]
        
        userAccelerationRef.setValue(data)
    }
}

struct AuthView: View {
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var isSignIn = true
    @State private var isShowingAlert = false
    @State private var alertMessage = ""
    @State private var isLoggedIn = false // Track the login status
    @State private var accelerationData: [AccelerationData] = []
    var body: some View {
        if isLoggedIn {
            Text("Welcome, \(Auth.auth().currentUser?.email ?? "")!")
                .font(.title)
                .padding()
                .onAppear {
                    loadAccelerationData()
                }
        } else {
            VStack {
                Text(isSignIn ? "Sign In" : "Sign Up")
                    .font(.title)
                    .padding()
                
                TextField("Email", text: $email)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal)
                
                SecureField("Password", text: $password)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal)
                
                Button(action: {
                    isSignIn ? signIn() : signUp()
                }) {
                    Text(isSignIn ? "Sign In" : "Sign Up")
                        .font(.headline)
                        .padding()
                        .foregroundColor(Color.white)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.blue)
                        )
                }
                .padding()
                
                Text(isSignIn ? "Don't have an account? Sign up" : "Already have an account? Sign in")
                    .foregroundColor(.blue)
                    .onTapGesture {
                        isSignIn.toggle()
                    }
            }
            .padding()
            .alert(isPresented: $isShowingAlert) {
                Alert(title: Text("Error"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
            }
        }
    }
    
    func signIn() {
        Auth.auth().signIn(withEmail: email, password: password) { result, error in
            if let error = error {
                alertMessage = error.localizedDescription
                isShowingAlert = true
            } else {
                isLoggedIn = true
            }
        }
    }
    
    func signUp() {
        Auth.auth().createUser(withEmail: email, password: password) { result, error in
            if let error = error {
                alertMessage = error.localizedDescription
                isShowingAlert = true
            } else {
                isLoggedIn = true
            }
        }
    }
    
    func loadAccelerationData() {
        guard let user = Auth.auth().currentUser else {
            return
        }
        
        let userId = user.uid
        let ref = Database.database().reference(withPath: "acceleration").child(userId)
        
        ref.observe(.value) { snapshot in
            var data: [AccelerationData] = []
            
            for child in snapshot.children {
                if let childSnapshot = child as? DataSnapshot,
                   let value = childSnapshot.value as? [String: Any],
                   let acceleration = value["acceleration"] as? Double,
                   let timestamp = value["timestamp"] as? TimeInterval {
                    let accelerationData = AccelerationData(acceleration: acceleration, timestamp: Date(timeIntervalSince1970: timestamp))
                    data.append(accelerationData)
                }
            }
            
            DispatchQueue.main.async {
                self.accelerationData = data
            }
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
    private let motionManager = CMMotionManager()
    private var timer: Timer?
    
    @Published var acceleration: Double = 0.0
    @Published var averageSpeed: Double = 0.0
    @Published var location: CLLocation?
    
    var updateInterval: Double = 1.0
    
    override init() {
        super.init()
        locationManager.delegate = self
    }
    
    func requestLocationAuthorization() {
        locationManager.requestWhenInUseAuthorization()
    }
    
    func startUpdatingLocation() {
        locationManager.startUpdatingLocation()
        startUpdatingMotion()
    }
    
    func stopUpdatingLocation() {
        locationManager.stopUpdatingLocation()
        stopUpdatingMotion()
    }
    
    func startUpdatingMotion() {
        motionManager.startAccelerometerUpdates()
        timer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { [weak self] _ in
            self?.processMotionData()
        }
    }
    
    func stopUpdatingMotion() {
        motionManager.stopAccelerometerUpdates()
        timer?.invalidate()
        timer = nil
    }
    
    private func processMotionData() {
        guard let accelerometerData = motionManager.accelerometerData else { return }
        
        let acceleration = sqrt(pow(accelerometerData.acceleration.x, 2) + pow(accelerometerData.acceleration.y, 2) + pow(accelerometerData.acceleration.z, 2))
        self.acceleration = acceleration
        
        guard let location = location else { return }
        
        averageSpeed = location.speed
    }

    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        self.location = location
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}






