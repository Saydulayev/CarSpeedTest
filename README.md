#### Preview

<table border=0>
    <tr>
        <td>
            <image src=https://github.com/Saydulayev/CarSpeedTest/blob/main/CarSpeedTest/Screenshots/acceleration.GIF width=230 align=center>
        </td>
    </tr>
</table>
                
# CarSpeedTest

Speed Tracker is an iOS application built using SwiftUI and Firebase that allows users to track their speed and acceleration while driving. The app provides real-time speed data, charts to visualize the speed history, and options to customize measurement settings. Users can also create an account to save their acceleration history securely.

## Features

- Real-time speed tracking: The app uses Core Location framework to track the user's speed in kilometers per hour or miles per hour. The speed data is displayed in the main view along with the selected unit.

- Acceleration tracking: The app calculates and displays the time taken to accelerate from 0 to 100 km/h (or mph) and from 0 to 200 km/h (or mph). The acceleration data is updated as the user's speed changes.

- Speed history chart: The app visualizes the speed history using a line chart. The chart shows the speed values over time, allowing users to analyze their driving patterns.

- Authentication: Users can create an account and sign in to access additional features like saving and viewing their acceleration history. Firebase Authentication is used for user authentication and account management.

- Customizable settings: Users can customize the measurement interval (the time interval between speed updates), display precision (the number of decimal places to display for speed values), and preferred speed unit (kilometers per hour or miles per hour) based on their preferences.

## Getting Started

To run the Speed Tracker app locally, follow these steps:

1. Clone the repository:

   ```
   git clone <repository-url>
   ```

2. Install dependencies:

   This project uses the Swift Package Manager for dependency management. Run the following command to install the required dependencies:

   ```
   cd SpeedTracker
   swift package resolve
   ```

3. Set up Firebase:

   - Create a new Firebase project at [https://firebase.google.com/](https://firebase.google.com/).
   - Enable Firebase Authentication and configure the desired authentication methods (email/password, Google Sign-In, etc.).
   - Enable the Firebase Realtime Database and set up the necessary security rules.

4. Configure Firebase in the app:

   - Open the Xcode project (`SpeedTracker.xcodeproj`) in Xcode.
   - Replace the placeholders in the `Info.plist` file with your own Firebase configuration details.
   - Update the Firebase URLs and paths in the `ContentView` and `AccelerationDataManager` classes with your own database references.

5. Build and run the app:

   - Select a simulator or a connected iOS device in Xcode.
   - Build and run the project using the `Cmd + R` shortcut.

## Usage

- Launch the Speed Tracker app on your iOS device or simulator.
- If you don't have an account, sign up by providing your email and password. If you already have an account, sign in using your credentials.
- Grant location permissions when prompted to allow the app to track your speed.
- The main view shows your current speed, the time taken to reach 100 km/h (or mph), and the time taken to reach 200 km/h (or mph).
- The line chart displays your speed history over time.
- Use the play button to start updating your speed and the stop button to stop updating.
- Use the gear icon in the tab bar to access the settings screen, where you can customize the measurement interval, display precision, and preferred speed unit.
- The history tab displays your saved acceleration history. You can search for specific entries using the search bar and delete the entire history if needed.
- Use the account tab to sign out or reset your password if you forget it.

## Contributing

Contributions to the Speed Tracker app are welcome! If you find any issues or want to add new features, feel free to open an issue or submit

 a pull request.

When contributing, please follow the existing code style and adhere to good programming practices. Additionally, make sure to test your changes thoroughly.


## Acknowledgments

- The app utilizes various libraries and frameworks, including SwiftUI, Core Location, SwiftUICharts, Firebase, FirebaseAuth, FirebaseDatabase, and KeychainAccess.
- The project structure and implementation are inspired by best practices and architectural patterns for SwiftUI app development.

## Contact

For any inquiries or questions, please contact [saydulayev.wien@gmail.com]

---
