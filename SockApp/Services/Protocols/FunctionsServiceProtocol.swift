import Foundation

// Define common or specific request/response structures for type safety.
// These can be expanded as needed.

// Example for checkUsernameAvailability
struct CheckUsernameAvailabilityRequest: Encodable {
    let username: String
}
struct CheckUsernameAvailabilityResponse: Decodable {
    let isAvailable: Bool
    // Add any other fields the function might return
}

// Example for createGroup
struct CreateGroupRequest: Encodable {
    let groupName: String
    let primaryColor: String?
    let secondaryColor: String?
    let groupProfilePictureUrl: String?
    // Add inviterUserId if needed by the function
}
struct CreateGroupResponse: Decodable {
    let success: Bool // Or just rely on Result for success/failure
    let groupId: String
    let inviteLinkCode: String? // Optional, as per current implementation
    let message: String? // Optional message
}

// Example for functions that return a generic success/message
struct GenericFunctionResponse: Decodable {
    let success: Bool
    let message: String?
    // Include other common fields if necessary, e.g., an 'id' or 'status'
}

// Example for processing an invite link
struct ProcessInviteLinkRequest: Encodable {
    let inviteLinkCode: String
}
// Response could be GenericFunctionResponse or more specific if needed

// Example for handling user leave/remove
struct HandleUserLeaveOrRemoveRequest: Encodable {
    let groupId: String
    let userIdToRemove: String // The user being removed or leaving
}

// Example for accepting/declining invitations
struct ProcessInvitationRequest: Encodable {
    let invitationId: String
}

// Example for blind username invite
struct ProcessBlindUsernameInviteRequest: Encodable {
    let targetUsername: String
    let groupId: String
}


enum FunctionsServiceError: Error {
    case networkError(underlyingError: Error)
    case decodingError(underlyingError: Error)
    case encodingError(underlyingError: Error)
    case serverError(message: String, details: Any?) // Simplified for now
    case functionError(name: String, message: String?, details: Any?) // Specific to a function call
    case unknownError(underlyingError: Error?)
}

protocol FunctionsServiceProtocol {
    // Generic function call for flexibility, using [String: Any] for request/response
    // This mirrors Firebase's dynamic nature but lacks some type safety.
    func callFunction(
        name: String,
        data: [String: Any]?,
        completion: @escaping (Result<[String: Any]?, Error>) -> Void // Response is also [String: Any]?
    )

    // Type-safe version (preferred)
    // Need to register or handle these types appropriately in the implementation.
    func callFunction<RequestDTO: Encodable, ResponseDTO: Decodable>(
        name: String,
        data: RequestDTO,
        responseType: ResponseDTO.Type,
        completion: @escaping (Result<ResponseDTO, Error>) -> Void
    )

    // Version for functions that don't require specific request DTO (or use [String:Any]) but have a specific response DTO
    func callFunction<ResponseDTO: Decodable>(
        name: String,
        data: [String: Any]?, // Or make data non-optional if functions always expect some input
        responseType: ResponseDTO.Type,
        completion: @escaping (Result<ResponseDTO, Error>) -> Void
    )
}
