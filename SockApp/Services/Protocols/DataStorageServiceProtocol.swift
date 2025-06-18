import Foundation

// Assuming model types (UserProfile, Group, Invitation) are globally available
// or will be imported from their respective files.

enum DataStorageError: Error {
    case decodingError(Error)
    case encodingError(Error)
    case underlyingError(Error) // Generic underlying error from the storage system
    case documentNotFound
    case operationFailed(String) // Custom message for failed operations
    // Add other specific storage errors as needed
}

protocol DataStorageServiceProtocol {
    // User Profile
    func createUserProfile(uid: String, data: UserProfile, completion: @escaping (Result<Void, Error>) -> Void)
    func updateUserProfile(uid: String, data: [String: Any], completion: @escaping (Result<Void, Error>) -> Void)
    func getUserProfile(uid: String, completion: @escaping (Result<UserProfile, Error>) -> Void)
    func addUserProfileListener(uid: String, completion: @escaping (Result<UserProfile, Error>) -> Void) -> ListenerRegistrationProtocol?

    // Groups
    // `createGroup` is a complex operation involving creating a group, adding user to it, etc.
    // This is currently handled by a Firebase Function (`createGroup`).
    // If we were to implement it client-side with abstracted DB calls, it would be more involved.
    // For now, let's assume group creation remains primarily a "Function" call.
    // func createGroup(data: Group, byUser: AuthUser, completion: @escaping (Result<String, Error>) -> Void) // Returns groupID

    func updateGroup(groupId: String, data: [String: Any], completion: @escaping (Result<Void, Error>) -> Void)
    func getGroup(groupId: String, completion: @escaping (Result<Group, Error>) -> Void)
    func addGroupListener(groupId: String, completion: @escaping (Result<Group, Error>) -> Void) -> ListenerRegistrationProtocol?
    func getGroups(groupIds: [String], completion: @escaping (Result<[Group], Error>) -> Void)
    // Querying groups by member might be a specific function or a more complex query method.
    // For now, the app fetches user's group list then fetches each group.

    // Invitations
    // Invitation creation, acceptance, decline are Firebase Functions.
    // Listing pending invitations is a direct query.
    func getPendingInvitations(userId: String, completion: @escaping (Result<[Invitation], Error>) -> Void) -> ListenerRegistrationProtocol?

    // Potentially a method to fetch user by username, if direct DB query is preferred over a function.
    // func getUserByUsername(username: String, completion: @escaping (Result<UserProfile?, Error>) -> Void)
}
