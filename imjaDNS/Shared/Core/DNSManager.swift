//
//  DNSManager.swift
//  imjaDNS
//
//  Created by Petros Dhespollari on 30/04/2025.
//

import Foundation

class DNSManager {
    static let shared = DNSManager()
    private init() {}

    func getCurrentDNS() -> String {
        #if os(macOS)
        let task = Process()
        task.launchPath = "/usr/sbin/scutil"
        task.arguments = ["--dns"]

        let pipe = Pipe()
        task.standardOutput = pipe

        task.launch()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        task.waitUntilExit()

        if let output = String(data: data, encoding: .utf8),
           let match = output.components(separatedBy: "nameserver ").dropFirst().first?.components(separatedBy: "\n").first {
            return match
        }
        return "Unknown"
        #else
        return "Auto-assigned"
        #endif
    }

    func changeDNS(to newDNS: String) {
        print("DNS changed to: \(newDNS)")
        // Actual change logic here (TBD)
    }
}
