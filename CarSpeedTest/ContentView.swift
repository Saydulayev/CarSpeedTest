//
//  ContentView.swift
//  CarSpeedTest
//
//  Created by Akhmed on 30.05.23.
//


import SwiftUI
import CoreLocation
import SwiftUICharts
import Firebase
import FirebaseAuth
import FirebaseDatabase
import KeychainAccess

struct ContentView: View {
    @Environment(\.colorScheme) var colorScheme
    @StateObject private var locationManager = LocationManager()
    @State private var speedData: [Double] = []
    @AppStorage("SelectedUnitIndex") private var selectedUnitIndex = 0
    @AppStorage("MeasurementInterval") private var measurementInterval = 1.0
    @AppStorage("DisplayPrecision") private var displayPrecision = 0
    
    @State private var timeTo100: TimeInterval = 0.0
    @State private var timeTo200: TimeInterval = 0.0
    @State private var isAccelerationStarted = false
    @State private var isAccelerationCompleted = false
    
    private let speedUnits: [String] = ["km/h", "mph"]
    
    var currentSpeedUnit: String {
        speedUnits[selectedUnitIndex]
    }
    
    var preferredSpeedUnit: String {
        if selectedUnitIndex == 0 {
            return "km/h"
        } else {
            return "mph"
        }
    }
    
    var body: some View {
        TabView {
            VStack {
                if Auth.auth().currentUser != nil {
                    if isAccelerationStarted {
                        Text("Acceleration Started")
                            .font(.title)
                            .padding()
                    }
                    
                    if isAccelerationCompleted {
                        Text("Acceleration Completed")
                            .font(.title)
                            .padding()
                    }
                    
                    Text("Time to 100 \(preferredSpeedUnit): \(timeTo100, specifier: "%.1f") seconds")
                    Text("Time to 200 \(preferredSpeedUnit): \(timeTo200, specifier: "%.1f") seconds")
                    Text("Speed: \(locationManager.averageSpeed, specifier: "%.\(displayPrecision)f") \(currentSpeedUnit)")
                        .font(.title)
                        .padding()
                } else {
                    Text("Please sign in to view the data")
                }
                
                LineChartView(data: speedData,
                              title: "Speed",
                              legend: "Speed",
                              style: ChartStyle(backgroundColor: .white,
                                                accentColor: .blue,
                                                gradientColor: GradientColor(start: .blue, end: .white),
                                                textColor: .black,
                                                legendTextColor: .gray,
                                                dropShadowColor: .gray),
                              form: CGSize(width: UIScreen.main.bounds.width - 20, height: 240))
                    .padding(.horizontal, 10)
                    .padding(30)
                
                HStack {
                    Button(action: {
                        locationManager.startUpdatingLocation()
                    }) {
                        Image(systemName: "play")
                            .font(.title)
                            .frame(width: 55, height: 55)
                            .padding()
                            .foregroundColor(colorScheme == .dark ? .white : .black)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(colorScheme == .dark ? .black : .white)
                                    .shadow(color: colorScheme == .dark ? Color.white.opacity(0.3) : Color.black.opacity(0.3), radius: 3, x: 0, y: 0)
                            )
                    }
                    .padding()
                    
                    Button(action: {
                        locationManager.stopUpdatingLocation()
                    }) {
                        Image(systemName: "stop")
                            .font(.title)
                            .frame(width: 55, height: 55)
                            .padding()
                            .foregroundColor(colorScheme == .dark ? .white : .black)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(colorScheme == .dark ? .black : .white)
                                    .shadow(color: colorScheme == .dark ? Color.white.opacity(0.3) : Color.black.opacity(0.3), radius: 3, x: 0, y: 0)
                            )
                    }
                    .padding()
                    
                    Button(action: {
                        resetAccelerationData()
                    }) {
                        Image(systemName: "gobackward")
                            .font(.title)
                            .frame(width: 55, height: 55)
                            .padding()
                            .foregroundColor(colorScheme == .dark ? .white : .black)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(colorScheme == .dark ? .black : .white)
                                    .shadow(color: colorScheme == .dark ? Color.white.opacity(0.3) : Color.black.opacity(0.3), radius: 3, x: 0, y: 0)
                            )
                    }
                    .padding()
                    
                }
                .padding(.horizontal)
                
            }
            .tabItem {
                Label("Speed", systemImage: "speedometer")
            }
            
            AccelerationHistoryView()
                .tabItem {
                    Label("History", systemImage: "clock")
                }
            
            AuthView()
                .tabItem {
                    Label("Account", systemImage: "person.fill")
                }
            
            SettingsView(measurementInterval: $measurementInterval,
                         displayPrecision: $displayPrecision,
                         selectedUnitIndex: $selectedUnitIndex)
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
        .onAppear {
            locationManager.requestLocationAuthorization()
            locationManager.updateInterval = measurementInterval
        }
        .onReceive(locationManager.$averageSpeed) { averageSpeed in
            DispatchQueue.main.async {
                let timestamp = Date()
                
                do {
                    try handleAccelerationUpdate(averageSpeed: averageSpeed, timestamp: timestamp)
                } catch {
                    print("Error handling acceleration update: \(error)")
                }
                
                speedData.append(averageSpeed)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
            locationManager.stopUpdatingLocation()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            if locationManager.averageSpeed != 0.0 {
                locationManager.startUpdatingLocation()
            }
        }
    }
    
    private func resetAccelerationData() {
        timeTo100 = 0.0
        timeTo200 = 0.0
        isAccelerationStarted = false
        isAccelerationCompleted = false
        speedData = []
    }
    
    private func saveAccelerationData(acceleration: Double, timestamp: Date) {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        let database = Database.database().reference()
        let userAccelerationRef = database.child("acceleration").child(userId)
        
        let data: [String: Any] = [
            "acceleration": acceleration,
            "speed": locationManager.averageSpeed,
            "timestamp": timestamp.timeIntervalSince1970
        ]
        
        userAccelerationRef.setValue(data) { error, _ in
            if let error = error {
                print("Failed to save acceleration data: \(error)")
            } else {
                do {
                    try handleAccelerationSave(acceleration: acceleration, timestamp: timestamp)
                } catch {
                    print("Error handling acceleration save: \(error)")
                }
            }
        }
    }
    
    private func handleAccelerationUpdate(averageSpeed: Double, timestamp: Date) throws {
        let acceleration = calculateAcceleration(speed: averageSpeed)
        try handleAccelerationStart(acceleration: acceleration)
        try handleTimeTo100Update(averageSpeed: averageSpeed, timestamp: timestamp)
        try handleTimeTo200Update(averageSpeed: averageSpeed, timestamp: timestamp)
    }
    
    private func handleAccelerationSave(acceleration: Double, timestamp: Date) throws {
        try handleAccelerationStart(acceleration: acceleration)
        try handleTimeTo100Save(acceleration: acceleration, timestamp: timestamp)
        try handleTimeTo200Save(acceleration: acceleration, timestamp: timestamp)
    }
    
    private func handleAccelerationStart(acceleration: Double) throws {
        if acceleration >= 0 && !isAccelerationStarted {
            isAccelerationStarted = true
        }
    }
    
    private func handleTimeTo100Update(averageSpeed: Double, timestamp: Date) throws {
        if timeTo100 == 0.0 && averageSpeed > 100.0 {
            if let firstTimestamp = locationManager.firstLocationTimestamp {
                timeTo100 = timestamp.timeIntervalSince(firstTimestamp)
            }
        }
    }
    
    private func handleTimeTo100Save(acceleration: Double, timestamp: Date) throws {
        if acceleration >= 100 && timeTo100 == 0.0 {
            if let firstTimestamp = locationManager.firstLocationTimestamp {
                timeTo100 = timestamp.timeIntervalSince(firstTimestamp)
            }
        }
    }
    
    private func handleTimeTo200Update(averageSpeed: Double, timestamp: Date) throws {
        if timeTo200 == 0.0 && averageSpeed >= 200.0 {
            if let firstTimestamp = locationManager.firstLocationTimestamp {
                timeTo200 = timestamp.timeIntervalSince(firstTimestamp)
                isAccelerationCompleted = true
            }
        }
    }
    
    private func handleTimeTo200Save(acceleration: Double, timestamp: Date) throws {
        if acceleration >= 200 && timeTo200 == 0.0 {
            if let firstTimestamp = locationManager.firstLocationTimestamp {
                timeTo200 = timestamp.timeIntervalSince(firstTimestamp)
                isAccelerationCompleted = true
            }
        }
    }
    
    private func calculateAcceleration(speed: Double) -> Double {
        // Perform acceleration calculation based on speed data
        // Return the calculated acceleration value
        return 0.0
    }
}

struct AccelerationHistoryView: View {
    @ObservedObject var accelerationDataManager = AccelerationDataManager()
    @State private var isShowingDeleteAlert = false
    @State private var searchText = ""
    
    var filteredAccelerationData: [AccelerationData] {
        accelerationDataManager.accelerationData.filter { acceleration in
            searchText.isEmpty || acceleration.timestampString.localizedStandardContains(searchText)
        }
    }
    
    var body: some View {
        VStack {
            SearchBar(text: $searchText)
                .padding(.horizontal)
            
            List(filteredAccelerationData) { acceleration in
                VStack(alignment: .leading) {
                    Text("Acceleration: \(acceleration.acceleration, specifier: "%.2f")")
                    Text("Speed: \(acceleration.speed, specifier: "%.2f")")
                    Text("Timestamp: \(acceleration.timestampString)")
                }
                .padding(.vertical)
            }
            
            Button(action: {
                isShowingDeleteAlert = true
            }) {
                Text("Delete History")
                    .font(.headline)
                    .padding()
                    .foregroundColor(.white)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(.red)
                    )
            }
            .padding()
            .alert(isPresented: $isShowingDeleteAlert) {
                Alert(title: Text("Delete History"),
                      message: Text("Are you sure you want to delete the acceleration history?"),
                      primaryButton: .destructive(Text("Delete")) {
                          accelerationDataManager.deleteAccelerationData()
                      },
                      secondaryButton: .cancel()
                )
            }
        }
        .onAppear {
            accelerationDataManager.loadAccelerationData()
        }
    }
}

struct SearchBar: View {
    @Binding var text: String
    
    var body: some View {
        HStack {
            TextField("Search", text: $text)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            
            if !text.isEmpty {
                Button(action: {
                    text = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
                .buttonStyle(BorderlessButtonStyle())
            }
        }
    }
}

struct AuthView: View {
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var confirmPassword: String = ""
    @State private var isSignIn = true
    @State private var isShowingAlert = false
    @State private var alertMessage = ""
    @State private var accelerationData: [AccelerationData] = []
    @State private var isLoggedIn = false // Track the login status
    let keychain = Keychain(service: "com.example.app") // Specify your app's identifier
    
    var body: some View {
        if isLoggedIn {
            VStack {
                Text("Welcome, \(Auth.auth().currentUser?.email ?? "")!")
                    .font(.title)
                    .padding()
                
                Button(action: {
                    signOut()
                }) {
                    Text("Sign Out")
                        .font(.headline)
                        .padding()
                        .foregroundColor(Color.white)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.red)
                        )
                }
                .padding()
                
                // Other views or functionality for the authenticated user
                
            }
            .onAppear {
                // Restore saved user credentials
                restoreUserCredentials()
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
                
                if !isSignIn {
                    SecureField("Confirm Password", text: $confirmPassword)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding(.horizontal)
                }
                
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
                
                if isSignIn {
                    Button(action: {
                        resetPassword()
                    }) {
                        Text("Forgot Password?")
                            .foregroundColor(.blue)
                            .padding()
                    }
                }
                
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
            .onAppear {
                // Check if user is already signed in
                checkUserSignIn()
            }
        }
    }
    
    func signIn() {
        Auth.auth().signIn(withEmail: email, password: password) { result, error in
            if let error = error {
                showAlert(message: error.localizedDescription)
            } else {
                saveUserCredentials()
                isLoggedIn = true
            }
        }
    }
    
    func signUp() {
        if password == confirmPassword {
            Auth.auth().createUser(withEmail: email, password: password) { result, error in
                if let error = error {
                    showAlert(message: error.localizedDescription)
                } else {
                    saveUserCredentials()
                    isLoggedIn = true
                }
            }
        } else {
            showAlert(message: "Passwords do not match.")
        }
    }
    
    func resetPassword() {
        Auth.auth().sendPasswordReset(withEmail: email) { error in
            if let error = error {
                showAlert(message: error.localizedDescription)
            } else {
                showAlert(message: "Password reset email sent.")
            }
        }
    }
    
    func signOut() {
        do {
            try Auth.auth().signOut()
            clearUserCredentials()
            isLoggedIn = false
        } catch {
            showAlert(message: error.localizedDescription)
        }
    }
    
    func showAlert(message: String) {
        alertMessage = message
        isShowingAlert = true
    }
    
    func checkUserSignIn() {
        if Auth.auth().currentUser != nil {
            isLoggedIn = true
        }
    }
    
    func saveUserCredentials() {
        do {
            try keychain.set(email, key: "email")
            try keychain.set(password, key: "password")
        } catch {
            showAlert(message: "Failed to save user credentials.")
        }
    }
    
    func restoreUserCredentials() {
        do {
            email = try keychain.get("email") ?? ""
            password = try keychain.get("password") ?? ""
        } catch {
            showAlert(message: "Failed to restore user credentials.")
        }
    }
    
    func clearUserCredentials() {
        do {
            try keychain.remove("email")
            try keychain.remove("password")
        } catch {
            showAlert(message: "Failed to clear user credentials.")
        }
    }
}

struct SettingsView: View {
    @Binding var measurementInterval: Double
    @Binding var displayPrecision: Int
    @Binding var selectedUnitIndex: Int
    
    private let measurementIntervals = [0.5, 1.0, 2.0, 5.0]
    private let displayPrecisions = [0, 1, 2]
    private let speedUnits: [String] = ["km/h", "mph"]

    
    var body: some View {
        VStack {
            Form {
                Section(header: Text("Measurement Interval")) {
                    Picker("Measurement Interval", selection: $measurementInterval) {
                        ForEach(measurementIntervals, id: \.self) { interval in
                            Text("\(interval, specifier: "%.1f") sec.")
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                
                Section(header: Text("Display Precision")) {
                    Picker("Display Precision", selection: $displayPrecision) {
                        ForEach(displayPrecisions, id: \.self) { precision in
                            Text("\(precision)")
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                
                Section(header: Text("Speed Unit")) {
                    Picker("Speed Unit", selection: $selectedUnitIndex) {
                        ForEach(0..<speedUnits.count) { index in
                            Text(speedUnits[index])
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
            }
        }
        .padding()
    }
}

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    
    @Published var averageSpeed: Double = 0.0
    var firstLocationTimestamp: Date?
    var updateInterval: TimeInterval = 1.0
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
    }
    
    func requestLocationAuthorization() {
        locationManager.requestWhenInUseAuthorization()
    }
    
    func startUpdatingLocation() {
        locationManager.startUpdatingLocation()
        firstLocationTimestamp = Date()
    }
    
    func stopUpdatingLocation() {
        locationManager.stopUpdatingLocation()
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        averageSpeed = location.speed
    }
}

class AccelerationDataManager: ObservableObject {
    @Published var accelerationData: [AccelerationData] = []
    
    func loadAccelerationData() {
        // Load acceleration data from the database and update the `accelerationData` property
        // with the retrieved data
    }
    
    func deleteAccelerationData() {
        // Delete acceleration data from the database and update the `accelerationData` property
        // by removing the deleted data
    }
}

struct AccelerationData: Identifiable {
    let id = UUID()
    let acceleration: Double
    let speed: Double
    let timestamp: Date
    
    var timestampString: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM d, yyyy 'at' h:mm a"
        return dateFormatter.string(from: timestamp)
    }
}



struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}











