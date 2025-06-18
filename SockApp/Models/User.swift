import FirebaseFirestore
import FirebaseFirestoreSwift

struct UserProfile: Identifiable, Codable {
    @DocumentID var id: String? // UID
    var username: String
    var email: String
    var createdAt: Timestamp?
    var groups: [String]? // Array of group IDs the user is a member of
    var globalStatusId: String?
    var groupSpecificStatuses: [String: String]? // Map of groupId to statusId

    // Default initializer
    init(id: String? = nil,
         username: String,
         email: String,
         createdAt: Timestamp? = Timestamp(date: Date()),
         groups: [String]? = [],
         globalStatusId: String? = nil,
         groupSpecificStatuses: [String: String]? = [:]) {
        self.id = id
        self.username = username
        self.email = email
        self.createdAt = createdAt
        self.groups = groups
        self.globalStatusId = globalStatusId
        self.groupSpecificStatuses = groupSpecificStatuses
    }
}
