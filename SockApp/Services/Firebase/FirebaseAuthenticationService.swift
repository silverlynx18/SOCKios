import Foundation
import FirebaseAuth

// Assuming AuthServiceProtocol and AuthUser are correctly imported or available globally.
// Ensure SockApp/Services/Protocols/AuthServiceProtocol.swift is part of the target.

class FirebaseAuthenticationService: AuthServiceProtocol {

    private let auth = Auth.auth()

    func getCurrentUser() -> AuthUser? {
        if let firebaseUser = auth.currentUser {
            return AuthUser(uid: firebaseUser.uid, email: firebaseUser.email)
        }
        return nil
    }

    func signUp(email: String, password: String, username: String, completion: @escaping (Result<AuthUser, Error>) -> Void) {
        // Note: 'username' is passed but not directly used by Firebase Auth's createUser.
        // The creation of the user profile (which includes the username) in Firestore
        // is handled separately by the DataStorageService after this auth step is successful.
        // This service focuses purely on the authentication aspect.
        auth.createUser(withEmail: email, password: password) { authResult, error in
            if let error = error {
                completion(.failure(AuthError.generalError(error)))
                return
            }
            guard let user = authResult?.user else {
                // Should not happen if error is nil, but good to guard.
                completion(.failure(AuthError.generalError(NSError(domain: "FirebaseAuth", code: -1, userInfo: [NSLocalizedDescriptionKey: "User object not found after sign up."]))))
                return
            }
            completion(.success(AuthUser(uid: user.uid, email: user.email)))
        }
    }

    func login(email: String, password: String, completion: @escaping (Result<AuthUser, Error>) -> Void) {
        auth.signIn(withEmail: email, password: password) { authResult, error in
            if let error = error {
                completion(.failure(AuthError.generalError(error)))
                return
            }
            guard let user = authResult?.user else {
                // Should not happen if error is nil.
                completion(.failure(AuthError.generalError(NSError(domain: "FirebaseAuth", code: -1, userInfo: [NSLocalizedDescriptionKey: "User object not found after login."]))))
                return
            }
            completion(.success(AuthUser(uid: user.uid, email: user.email)))
        }
    }

    func signOut(completion: @escaping (Error?) -> Void) {
        do {
            try auth.signOut()
            completion(nil)
        } catch let error {
            completion(AuthError.generalError(error))
        }
    }
}
