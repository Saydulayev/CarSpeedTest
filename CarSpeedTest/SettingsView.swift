//
//  SettingsView.swift
//  CarSpeedTest
//
//  Created by Dokx Dig on 30.05.23.
//

import SwiftUI

struct SettingsView: View {
    @AppStorage("appTheme") private var appTheme: AppTheme = .system

    var body: some View {
        Form {
            Section(header: Text("Theme")) {
                Picker("App Theme", selection: $appTheme) {
                    Text("System").tag(AppTheme.system)
                    Text("Light").tag(AppTheme.light)
                    Text("Dark").tag(AppTheme.dark)
                    Text("Custom").tag(AppTheme.custom)
                }
                .pickerStyle(SegmentedPickerStyle())
            }
        }
        .navigationTitle("Settings")
    }
}

enum AppTheme: String, CaseIterable, Identifiable {
    case system
    case light
    case dark
    case custom

    var id: String { self.rawValue }

    var colorScheme: ColorScheme? {
        switch self {
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        case .custom:
            return nil // Implement custom theme logic here
        }
    }
}



struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
