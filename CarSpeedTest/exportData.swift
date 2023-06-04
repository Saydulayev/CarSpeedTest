//
//  exportData.swift
//  CarSpeedTest
//
//  Created by Akhmed on 31.05.23.
//


import Foundation

func exportData(historyStore: HistoryStore) {
        let fileName = "AccelerationData.csv"
        let fileURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(fileName)
        
        var csvText = "Acceleration,Timestamp\n"
        
        for data in historyStore.accelerationData {
            let accelerationString = String(format: "%.2f", data.acceleration)
            let timestampString = data.timestampString
            let line = "\(accelerationString),\(timestampString)\n"
            csvText.append(line)
        }
        
        do {
            try csvText.write(to: fileURL, atomically: true, encoding: .utf8)
            print("Acceleration data exported successfully: \(fileURL.path)")
        } catch {
            print("Error exporting acceleration data: \(error.localizedDescription)")
        }
    }

