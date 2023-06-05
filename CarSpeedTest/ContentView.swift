//
//  ContentView.swift
//  CarSpeedTest
//
//  Created by Akhmed on 30.05.23.
//

import SwiftUI
import CoreLocation
import SwiftUICharts
import UIKit
import Firebase
import FirebaseAuth
import FirebaseCore


struct ContentView: View {
    @EnvironmentObject var historyStore: HistoryStore // Use the injected HistoryStore
    @Environment(\.colorScheme) var colorScheme
    @StateObject private var locationManager = LocationManager()
    @State private var accelerationData: [AccelerationData] = []
    @AppStorage("SelectedUnitIndex") private var selectedUnitIndex = 0 // Use AppStorage to observe and store the selected unit index
    @State private var measurementInterval = UserDefaults.standard.double(forKey: "MeasurementInterval")
    @State private var displayPrecision = UserDefaults.standard.integer(forKey: "DisplayPrecision")
    @State private var isShowingShareSheet = false
    @State private var loggedIn: Bool = false

    
    
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
            AuthenticationView(loggedIn: $loggedIn)
                .tabItem {
                    Label("Authentication", systemImage: "person.crop.circle.badge.plus")
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

struct AuthenticationView: View {
    @Binding var loggedIn: Bool
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var confirmPassword: String = ""
    @State private var showPassword: Bool = false
    @State private var error: String = ""
    @State private var registrationMode: Bool = true
    
    var body: some View {
        VStack {
            TextField("Email", text: $email)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()
            
            SecureField("Password", text: $password)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()
            
            if registrationMode {
                SecureField("Confirm Password", text: $confirmPassword)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding()
            }
            
            HStack {
                if registrationMode {
                    Button(action: register) {
                        Text("Register")
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.blue)
                            .cornerRadius(8)
                    }
                    .padding(.vertical, 10)
                } else {
                    Button(action: login) {
                        Text("Login")
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.blue)
                            .cornerRadius(8)
                    }
                    .padding(.vertical, 10)
                }
            }
            
            Button(action: {
                registrationMode.toggle()
            }) {
                Text(registrationMode ? "Switch to Login" : "Switch to Registration")
            }
            .padding(.vertical, 10)
            
            if !error.isEmpty {
                Text(error)
                    .foregroundColor(.red)
                    .padding(.top, 10)
            }
            
            if loggedIn {
                Text("Logged in successfully!")
                    .foregroundColor(.green)
                    .padding()
            }
        }
        .padding()
    }
    
    private func register() {
        if password == confirmPassword {
            Auth.auth().createUser(withEmail: email, password: password) { authResult, error in
                if let error = error {
                    self.error = "Error registering user: \(error.localizedDescription)"
                } else {
                    authResult?.user.sendEmailVerification(completion: { error in
                        if let error = error {
                            self.error = "Error sending email verification: \(error.localizedDescription)"
                        } else {
                            print("Email verification sent")
                        }
                    })
                    loggedIn = true
                }
            }
        } else {
            self.error = "Passwords do not match"
        }
    }
    
    private func login() {
        Auth.auth().signIn(withEmail: email, password: password) { authResult, error in
            if let error = error {
                self.error = "Error logging in: \(error.localizedDescription)"
            } else {
                print("Logged in")
                loggedIn = true
            }
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

class AppDelegate: NSObject, UIApplicationDelegate {
  func application(_ application: UIApplication,
                   didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
    FirebaseApp.configure()

    return true
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



struct RegistrationView: View {
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var confirmPassword: String = ""
    
    var body: some View {
        VStack {
            TextField("Email", text: $email)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()
            
            SecureField("Password", text: $password)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()
            
            SecureField("Confirm Password", text: $confirmPassword)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()
            
            Button("Register") {
                // Perform registration logic here
            }
            .padding()
        }
        .padding()
    }
}

struct LoginView: View {
    @State private var email: String = ""
    @State private var password: String = ""
    
    var body: some View {
        VStack {
            TextField("Email", text: $email)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()
            
            SecureField("Password", text: $password)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()
            
            Button("Login") {
                // Perform login logic here
            }
            .padding()
        }
        .padding()
    }
}


struct HistoryItem {
    let date: Date
    let speed: Double
    // Добавьте другие свойства по необходимости
}

class HistoryViewController: UIViewController {

    @IBOutlet private weak var emailTextField: UITextField!
    @IBOutlet private weak var passwordTextField: UITextField!
    @IBOutlet private weak var loginButton: UIButton!
    @IBOutlet private weak var registerButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupNavigationBar()
        FirebaseApp.configure()
    }
    
    private func setupNavigationBar() {
        let navigationBar = UINavigationBar(frame: CGRect(x: 0, y: 0, width: view.frame.width, height: 44))
        navigationBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(navigationBar)
        
        let navigationItem = UINavigationItem(title: "История")
        navigationBar.setItems([navigationItem], animated: false)
    }
    
    @IBAction private func loginButtonTapped(_ sender: UIButton) {
        guard let email = emailTextField.text,
              let password = passwordTextField.text else {
            return
        }
        
        Auth.auth().signIn(withEmail: email, password: password) { [weak self] result, error in
            guard let self = self else { return }
            
            if let error = error {
                self.showAlert(title: "Error", message: error.localizedDescription)
            } else {
                self.fetchHistory()
            }
        }
    }
    
    @IBAction private func registerButtonTapped(_ sender: UIButton) {
        guard let email = emailTextField.text,
              let password = passwordTextField.text else {
            return
        }
        
        Auth.auth().createUser(withEmail: email, password: password) { [weak self] result, error in
            guard let self = self else { return }
            
            if let error = error {
                self.showAlert(title: "Error", message: error.localizedDescription)
            } else {
                self.fetchHistory()
            }
        }
    }
    
    private func saveHistoryItem(_ item: HistoryItem) {
        guard let currentUserID = Auth.auth().currentUser?.uid else {
            return
        }
        
        let historyRef = Database.database().reference().child("history").child(currentUserID)
        let itemRef = historyRef.childByAutoId()
        
        let itemData: [String: Any] = [
            "date": item.date.timeIntervalSince1970,
            "speed": item.speed
            // Добавьте другие свойства по необходимости
        ]
        
        itemRef.setValue(itemData) { error, _ in
            if let error = error {
                print("Failed to save history item: \(error.localizedDescription)")
            } else {
                print("History item saved successfully")
            }
        }
    }
    
    private func fetchHistory() {
        guard let currentUserID = Auth.auth().currentUser?.uid else {
            return
        }
        
        let historyRef = Database.database().reference().child("history").child(currentUserID)
        
        historyRef.observeSingleEvent(of: .value) { snapshot in
            guard let historySnapshot = snapshot.children.allObjects as? [DataSnapshot] else {
                return
            }
            
            let historyItems = historySnapshot.compactMap { snapshot -> HistoryItem? in
                guard let itemData = snapshot.value as? [String: Any],
                      let dateTimestamp = itemData["date"] as? TimeInterval,
                      let speed = itemData["speed"] as? Double
                else {
                    return nil
                }
                
                let date = Date(timeIntervalSince1970: dateTimestamp)
                return HistoryItem(date: date, speed: speed)
            }
            
            print("Fetched \(historyItems.count) history items")
            // Делайте необходимые операции с полученными элементами истории
        }
    }
    
    private func showAlert(title: String, message: String) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let okAction = UIAlertAction(title: "OK", style: .default, handler: nil)
        alertController.addAction(okAction)
        present(alertController, animated: true, completion: nil)
    }
}







class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    @Published var acceleration: Double = 0.0
    @Published var averageSpeed: CLLocationAccuracy = 0.0

    var updateInterval: Double = 1.0
    
    override init() {
            super.init()
            locationManager.delegate = self
            locationManager.desiredAccuracy = kCLLocationAccuracyBest
            locationManager.distanceFilter = 1.0
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
        
        let currentSpeed: CLLocationSpeed = lastLocation.speed
        let acceleration = calculateAcceleration(from: currentSpeed)
        
        averageSpeed = CLLocationAccuracy(currentSpeed)
        self.acceleration = acceleration
    }

    
    private func calculateAcceleration(from speed: CLLocationSpeed) -> Double {
        let initialSpeed = 0.0
        let targetSpeeds = [100.0, 200.0]
        let timeInterval = 30.0 // Time interval during which the results are measured
        
        if speed >= initialSpeed && speed <= targetSpeeds[0] {
            // Measurement of acceleration from 0 to 100 km/h
            return (speed - initialSpeed) / timeInterval
        } else if speed > targetSpeeds[0] && speed <= targetSpeeds[1] {
            // Measurement of acceleration from 0 to 200 km/h
            let accelerationRange = targetSpeeds[1] - initialSpeed
            let timeRange = timeInterval
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

