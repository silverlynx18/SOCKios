import Foundation
import FirebaseFirestore
import FirebaseFirestoreSwift // For Codable support with Firestore

// Ensure model types (UserProfile, Group, Invitation) and protocols
// (DataStorageServiceProtocol, ListenerRegistrationProtocol) are correctly imported or available.
// Ensure FirebaseListenerRegistration is also available.

class FirebaseDataStorageService: DataStorageServiceProtocol {
    private let db = Firestore.firestore()

    // MARK: - User Profile
    func createUserProfile(uid: String, data: UserProfile, completion: @escaping (Result<Void, Error>) -> Void) {
        do {
            try db.collection("users").document(uid).setData(from: data) { error in
                if let error = error {
                    completion(.failure(DataStorageError.underlyingError(error)))
                } else {
                    completion(.success(()))
                }
            }
        } catch let error {
            completion(.failure(DataStorageError.encodingError(error)))
        }
    }

    func updateUserProfile(uid: String, data: [String : Any], completion: @escaping (Result<Void, Error>) -> Void) {
        db.collection("users").document(uid).updateData(data) { error in
            if let error = error {
                completion(.failure(DataStorageError.underlyingError(error)))
            } else {
                completion(.success(()))
            }
        }
    }

    func getUserProfile(uid: String, completion: @escaping (Result<UserProfile, Error>) -> Void) {
        db.collection("users").document(uid).getDocument { documentSnapshot, error in
            if let error = error {
                completion(.failure(DataStorageError.underlyingError(error)))
                return
            }
            guard let document = documentSnapshot, document.exists else {
                completion(.failure(DataStorageError.documentNotFound))
                return
            }
            do {
                let userProfile = try document.data(as: UserProfile.self)
                completion(.success(userProfile))
            } catch let error {
                completion(.failure(DataStorageError.decodingError(error)))
            }
        }
    }

    func addUserProfileListener(uid: String, completion: @escaping (Result<UserProfile, Error>) -> Void) -> ListenerRegistrationProtocol? {
        let listener = db.collection("users").document(uid).addSnapshotListener { documentSnapshot, error in
            if let error = error {
                completion(.failure(DataStorageError.underlyingError(error)))
                return
            }
            guard let document = documentSnapshot, document.exists else {
                completion(.failure(DataStorageError.documentNotFound))
                return
            }
            do {
                let userProfile = try document.data(as: UserProfile.self)
                completion(.success(userProfile))
            } catch let error {
                completion(.failure(DataStorageError.decodingError(error)))
            }
        }
        return FirebaseListenerRegistration(listener)
    }

    // MARK: - Groups
    func updateGroup(groupId: String, data: [String : Any], completion: @escaping (Result<Void, Error>) -> Void) {
        db.collection("groups").document(groupId).updateData(data) { error in
            if let error = error {
                completion(.failure(DataStorageError.underlyingError(error)))
            } else {
                completion(.success(()))
            }
        }
    }

    func getGroup(groupId: String, completion: @escaping (Result<Group, Error>) -> Void) {
        db.collection("groups").document(groupId).getDocument { documentSnapshot, error in
            if let error = error {
                completion(.failure(DataStorageError.underlyingError(error)))
                return
            }
            guard let document = documentSnapshot, document.exists else {
                completion(.failure(DataStorageError.documentNotFound))
                return
            }
            do {
                let group = try document.data(as: Group.self)
                completion(.success(group))
            } catch let error {
                completion(.failure(DataStorageError.decodingError(error)))
            }
        }
    }

    func addGroupListener(groupId: String, completion: @escaping (Result<Group, Error>) -> Void) -> ListenerRegistrationProtocol? {
        let listener = db.collection("groups").document(groupId).addSnapshotListener { documentSnapshot, error in
            if let error = error {
                completion(.failure(DataStorageError.underlyingError(error)))
                return
            }
            guard let document = documentSnapshot, document.exists else {
                completion(.failure(DataStorageError.documentNotFound))
                return
            }
            do {
                let group = try document.data(as: Group.self)
                completion(.success(group))
            } catch let error {
                completion(.failure(DataStorageError.decodingError(error)))
            }
        }
        return FirebaseListenerRegistration(listener)
    }

    func getGroups(groupIds: [String], completion: @escaping (Result<[Group], Error>) -> Void) {
        if groupIds.isEmpty {
            completion(.success([]))
            return
        }

        let dispatchGroup = DispatchGroup()
        var fetchedGroups: [Group] = []
        var errors: [Error] = []

        for groupId in groupIds {
            dispatchGroup.enter()
            db.collection("groups").document(groupId).getDocument { (document, error) in
                defer { dispatchGroup.leave() }
                if let error = error {
                    errors.append(DataStorageError.underlyingError(error))
                    return
                }
                if let document = document, document.exists {
                    do {
                        let group = try document.data(as: Group.self)
                        fetchedGroups.append(group)
                    } catch let decodeError {
                        errors.append(DataStorageError.decodingError(decodeError))
                    }
                } else {
                    // You might want to decide if a missing group is an error or just means it's not included.
                    // For now, let's treat it as a partial success if other groups are found.
                    // If it should be an overall failure, append DataStorageError.documentNotFound
                    print("Warning: Group document \(groupId) does not exist during getGroups fetch.")
                }
            }
        }

        dispatchGroup.notify(queue: .main) {
            if !errors.isEmpty && fetchedGroups.isEmpty {
                // If there were errors and no groups were successfully fetched, return the first error.
                completion(.failure(errors.first!))
            } else if !errors.isEmpty && !fetchedGroups.isEmpty {
                // Partial success: some groups fetched, but some errors occurred.
                // Log errors or handle as per application requirements. For now, return success with what was fetched.
                print("Warning: Errors occurred while fetching some groups: \(errors)")
                completion(.success(fetchedGroups.sorted(by: { $0.groupName.lowercased() < $1.groupName.lowercased() })))
            }
            else {
                // Full success
                completion(.success(fetchedGroups.sorted(by: { $0.groupName.lowercased() < $1.groupName.lowercased() })))
            }
        }
    }

    // MARK: - Invitations
    func getPendingInvitations(userId: String, completion: @escaping (Result<[Invitation], Error>) -> Void) -> ListenerRegistrationProtocol? {
        let query = db.collection("invitations")
            .whereField("invitedUserID", isEqualTo: userId)
            .whereField("status", isEqualTo: "pending")
            .order(by: "createdAt", descending: true)

        let listener = query.addSnapshotListener { querySnapshot, error in
            if let error = error {
                completion(.failure(DataStorageError.underlyingError(error)))
                return
            }
            guard let documents = querySnapshot?.documents else {
                // This case might mean no documents match, which is not an error itself.
                completion(.success([]))
                return
            }

            let invitations: [Invitation] = documents.compactMap { document -> Invitation? in
                do {
                    return try document.data(as: Invitation.self)
                } catch let decodeError {
                    // Log error for the specific document, but try to process others.
                    print("Error decoding invitation document \(document.documentID): \(decodeError)")
                    // Optionally, you could collect these errors and report them.
                    // For now, we'll return nil for this item, and it will be filtered out by compactMap.
                    // If a single decoding error should fail the whole operation, change logic here.
                    if let outerCompletion = completion as? (Result<[Invitation], Error>) -> Void {
                        // This is a bit tricky. We want to call completion with failure for this specific item,
                        // but the snapshot listener expects one result for the whole query.
                        // The current compactMap approach means problematic items are just skipped.
                        // If a single error should fail all, we'd need to check for any error in compactMap
                        // and then call completion(.failure) outside it.
                    }
                    return nil
                }
            }

            // Check if any decoding error occurred that should fail the entire operation
            // This is a simplified check. A more robust way would be to collect errors during compactMap.
            if invitations.count != documents.count && !documents.isEmpty && invitations.isEmpty {
                 // This implies all documents failed to decode, which is a significant issue.
                 completion(.failure(DataStorageError.decodingError(NSError(domain: "DataStorage", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to decode any invitation documents."]))))
            } else {
                 completion(.success(invitations))
            }
        }
        return FirebaseListenerRegistration(listener)
    }
}
