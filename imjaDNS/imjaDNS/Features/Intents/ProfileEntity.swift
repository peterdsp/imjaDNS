import AppIntents

/// App Intents representation of a DNS profile, so Shortcuts/Siri can show a
/// live picker of the user's profiles.
struct ProfileEntity: AppEntity {
    let id: UUID
    let name: String
    let serversDisplay: String

    static var typeDisplayRepresentation: TypeDisplayRepresentation { "DNS Profile" }
    static var defaultQuery = ProfileEntityQuery()

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)", subtitle: "\(serversDisplay)")
    }

    init(id: UUID, name: String, serversDisplay: String) {
        self.id = id
        self.name = name
        self.serversDisplay = serversDisplay
    }

    init(_ profile: DNSProfile) {
        self.init(id: profile.id, name: profile.name, serversDisplay: profile.serversDisplay)
    }
}

struct ProfileEntityQuery: EntityQuery {
    func entities(for identifiers: [UUID]) async throws -> [ProfileEntity] {
        await ProfileProvider.allProfiles()
            .filter { identifiers.contains($0.id) }
            .map(ProfileEntity.init)
    }

    func suggestedEntities() async throws -> [ProfileEntity] {
        await ProfileProvider.allProfiles().map(ProfileEntity.init)
    }
}
