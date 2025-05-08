//
//  DNSProfile.swift
//  imjaDNS
//
//  Created by Petros Dhespollari on 30/04/2025.
//

import Foundation

struct DNSProfile: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    let servers: [String]
}
