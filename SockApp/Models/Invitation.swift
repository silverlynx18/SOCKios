import FirebaseFirestore
import FirebaseFirestoreSwift

struct Invitation: Identifiable, Codable, Hashable {
    @DocumentID var id: String?
    var groupId: String
    var groupName: String? // Denormalized for easier display
    var invitedUserID: String
    var inviterUserID: String? // ID of the user who sent the invitation
    var status: String // e.g., "pending", "accepted", "declined"
    var createdAt: Timestamp?
    var expiresAt: Timestamp? // If invitations can expire

    // Conform to Hashable for use in diffable data sources or sets if needed
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: Invitation, rhs: Invitation) -> Bool {
        lhs.id == rhs.id
    }
}
