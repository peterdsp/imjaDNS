//
//  DNSProfile.swift
//  imjaDNS
//
//  Created by Petros Dhespollari on 30/04/2025.
//

import Foundation

struct DNSProfile: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var servers: [String]

    init(id: UUID = UUID(), name: String, servers: [String]) {
        self.id = id
        self.name = name
        self.servers = servers
    }
}
