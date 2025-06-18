import Foundation

enum AuthError: Error {
    case notLoggedIn
    case generalError(Error)
    // Add other specific auth errors
}

struct AuthUser { // A simple representation of an authenticated user
    let uid: String
    let email: String?
    // Consider adding username if it's commonly needed immediately after auth
}

protocol AuthServiceProtocol {
    func getCurrentUser() -> AuthUser?
    func signUp(email: String, password: String, username: String, completion: @escaping (Result<AuthUser, Error>) -> Void)
    func login(email: String, password: String, completion: @escaping (Result<AuthUser, Error>) -> Void)
    func signOut(completion: @escaping (Error?) -> Void)
    // Note: Account deletion is currently a Firebase Function, so it would go into FunctionsServiceProtocol
    // If it were a direct Auth SDK call, it would be here.
}
