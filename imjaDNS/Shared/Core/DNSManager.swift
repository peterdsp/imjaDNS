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
        // Placeholder for actual DNS fetching logic
        return "1.1.1.1"
    }

    func changeDNS(to newDNS: String) {
        // Placeholder for DNS update logic
        print("DNS changed to: \(newDNS)")
    }
}
