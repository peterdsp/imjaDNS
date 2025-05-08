//
//  DNSProfile.swift
//  imjaDNS
//
//  Created by Petros Dhespollari on 30/04/2025.
//

import Foundation

struct DNSProfile: Identifiable, Codable, Equatable {
    let id: UUID
    let name: String
    let servers: String

    // Custom decoding to generate `id` if missing in JSON
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        servers = try container.decode(String.self, forKey: .servers)

        // Try to decode id, otherwise generate one
        id = (try? container.decode(UUID.self, forKey: .id)) ?? UUID()
    }

    // Default initializer
    init(id: UUID = UUID(), name: String, servers: String) {
        self.id = id
        self.name = name
        self.servers = servers
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case servers
    }
}
