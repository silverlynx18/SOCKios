import FirebaseFirestoreSwift // Required for @DocumentID

struct Group: Identifiable, Codable, Hashable {
    @DocumentID var id: String? // Firestore document ID, maps to 'id' if field exists, or populates from doc ID
    var groupName: String
    var primaryColor: String?
    var secondaryColor: String?
    var groupProfilePictureUrl: String?
    var members: [String: String]? // Map of user UIDs to roles (e.g., "admin", "member")
    var createdAt: Date?
    var createdBy: String?
    var inviteLinkCode: String? // New property for the invite code

    // Conform to Hashable for use in diffable data sources or sets if needed
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: Group, rhs: Group) -> Bool {
        lhs.id == rhs.id
    }
}
