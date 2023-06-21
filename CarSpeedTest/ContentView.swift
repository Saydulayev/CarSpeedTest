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
    
    func saveAccelerationData(acceleration: Double, timestamp: Date) {
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
    
//    private func handleTimeTo100Update(averageSpeed: Double, timestamp: Date) throws {
//        if timeTo100 == 0.0 && averageSpeed >= 100.0 {
//            if let firstTimestamp = locationManager.firstLocationTimestamp {
//                timeTo100 = timestamp.timeIntervalSince(firstTimestamp)
//            }
//        }
//    }
    
    private func handleTimeTo100Update(averageSpeed: Double, timestamp: Date) throws {
        if timeTo100 == 0.0 && averageSpeed > 0.0 {
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
    let keychain = Keychain(service: "com.example.app") // Укажите идентификатор вашего приложения
    
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
                alertMessage = error.localizedDescription
                isShowingAlert = true
            } else {
                isLoggedIn = true
                saveUserCredentials() // Save user credentials upon successful sign-in
                email = ""
                password = ""
            }
        }
    }
    
    func signUp() {
        guard password == confirmPassword else {
            alertMessage = "Passwords do not match"
            isShowingAlert = true
            return
        }
        
        Auth.auth().createUser(withEmail: email, password: password) { result, error in
            if let error = error {
                alertMessage = error.localizedDescription
                isShowingAlert = true
            } else {
                sendVerificationEmail() // Send verification email upon successful sign-up
            }
        }
    }
    
    func signOut() {
        do {
            try Auth.auth().signOut()
            isLoggedIn = false
            clearUserCredentials() // Clear saved user credentials upon sign-out
        } catch let error {
            alertMessage = error.localizedDescription
            isShowingAlert = true
        }
    }
    
    func resetPassword() {
        Auth.auth().sendPasswordReset(withEmail: email) { error in
            if let error = error {
                alertMessage = error.localizedDescription
                isShowingAlert = true
            } else {
                alertMessage = "Password reset email has been sent. Please check your inbox."
                isShowingAlert = true
            }
        }
    }
    
    func sendVerificationEmail() {
        Auth.auth().currentUser?.sendEmailVerification { error in
            if let error = error {
                alertMessage = error.localizedDescription
                isShowingAlert = true
            } else {
                alertMessage = "Verification email has been sent. Please check your inbox."
                isShowingAlert = true
            }
        }
    }
    
    // Save user credentials to Keychain
    func saveUserCredentials() {
        do {
            try keychain.set(email, key: "UserEmail")
            try keychain.set(password, key: "UserPassword")
        } catch let error {
            print("Error saving user credentials: \(error.localizedDescription)")
        }
    }
    
    // Restore saved user credentials from Keychain
    func restoreUserCredentials() {
        do {
            if let savedEmail = try keychain.get("UserEmail"),
               let savedPassword = try keychain.get("UserPassword") {
                email = savedEmail
                password = savedPassword
            }
        } catch let error {
            print("Error restoring user credentials: \(error.localizedDescription)")
        }
    }
    
    // Clear saved user credentials from Keychain
    func clearUserCredentials() {
        do {
            try keychain.remove("UserEmail")
            try keychain.remove("UserPassword")
        } catch let error {
            print("Error clearing user credentials: \(error.localizedDescription)")
        }
    }
    
    // Check if user is already signed in
    func checkUserSignIn() {
        if Auth.auth().currentUser != nil {
            isLoggedIn = true
        }
    }
}

struct AccelerationData: Identifiable, Equatable {
    var id = UUID()
    let acceleration: Double
    let speed: Double
    let timestamp: Date
    
    var timestampString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, HH:mm:ss"
        return formatter.string(from: timestamp)
    }
}

class AccelerationDataManager: ObservableObject {
    @Published var accelerationData: [AccelerationData] = []
    
    init() {
        loadAccelerationData()
    }
    
    func loadAccelerationData() {
        guard let currentUserID = Auth.auth().currentUser?.uid else {
            accelerationData = [] // If the user is not authenticated, reset the data
            return
        }
        
        let ref = Database.database().reference(withPath: "acceleration").child(currentUserID)
        
        ref.observeSingleEvent(of: .value) { [weak self] snapshot in
            var data: [AccelerationData] = []
            
            for child in snapshot.children {
                if let childSnapshot = child as? DataSnapshot,
                   let value = childSnapshot.value as? [String: Any],
                   let acceleration = value["acceleration"] as? Double,
                   let speed = value["speed"] as? Double,
                   let timestamp = value["timestamp"] as? TimeInterval {
                    
                    let accelerationData = AccelerationData(acceleration: acceleration, speed: speed, timestamp: Date(timeIntervalSince1970: timestamp))
                    
                    data.append(accelerationData)
                }
            }
            
            DispatchQueue.main.async {
                self?.accelerationData = data
            }
        }
    }
    
    func deleteAccelerationData() {
        guard let currentUserID = Auth.auth().currentUser?.uid else {
            return
        }
        
        let ref = Database.database().reference(withPath: "acceleration").child(currentUserID)
        
        ref.removeValue { [weak self] error, _ in
            if let error = error {
                print("Failed to delete acceleration data: \(error)")
            } else {
                print("Acceleration data deleted successfully")
                self?.accelerationData = [] // Reset the data after deletion
            }
        }
    }
}

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    
    @Published var averageSpeed: Double = 0.0
    var firstLocationTimestamp: Date?
    
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
    }
    
    func stopUpdatingLocation() {
        locationManager.stopUpdatingLocation()
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        if firstLocationTimestamp == nil {
            firstLocationTimestamp = location.timestamp
        }
        
        averageSpeed = location.speed
    }
}

struct SettingsView: View {
    @Binding var measurementInterval: Double
    @Binding var displayPrecision: Int
    @Binding var selectedUnitIndex: Int
    
    private let speedUnits: [String] = ["km/h", "mph"]
    
    var body: some View {
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
        .navigationBarTitle("Settings")
    }
}


struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}











