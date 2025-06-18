import Foundation
import FirebaseFunctions

// Assuming FunctionsServiceProtocol, FunctionsServiceError, and DTOs are correctly imported or available globally.

class FirebaseFunctionsService: FunctionsServiceProtocol {
    private lazy var functions = Functions.functions()
    // Optional: Define a default region if your functions are not in us-central1
    // functions = Functions.functions(region: "your-region")

    // Generic [String: Any] version for direct passthrough or simple cases
    func callFunction(
        name: String,
        data: [String: Any]?,
        completion: @escaping (Result<[String: Any]?, Error>) -> Void
    ) {
        functions.httpsCallable(name).call(data) { result, error in
            if let error = error {
                completion(.failure(self.mapFirebaseError(error, forFunction: name)))
                return
            }

            // Check if the function returned any data at all
            guard let responseData = result?.data else {
                // If no data, it could be a void success or an issue.
                // For this generic call, we'll assume nil data is a valid success scenario for some functions.
                completion(.success(nil))
                return
            }

            if let dictResponse = responseData as? [String: Any] {
                completion(.success(dictResponse))
            } else {
                // If data is present but not a dictionary, this is unexpected for this generic signature.
                completion(.failure(FunctionsServiceError.decodingError(
                    underlyingError: NSError(domain: "FirebaseFunctionsService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Response data for \(name) was not in the expected [String: Any] format."])
                )))
            }
        }
    }

    // Type-safe version with Encodable request and Decodable response
    func callFunction<RequestDTO: Encodable, ResponseDTO: Decodable>(
        name: String,
        data: RequestDTO,
        responseType: ResponseDTO.Type, // Parameter kept for clarity, though not strictly needed if ResponseDTO is generic
        completion: @escaping (Result<ResponseDTO, Error>) -> Void
    ) {
        var dictData: [String: Any]?
        do {
            // Check if data is already [String: Any] to avoid unnecessary re-encoding
            if let alreadyDict = data as? [String: Any] {
                dictData = alreadyDict
            } else {
                let jsonData = try JSONEncoder().encode(data)
                dictData = try JSONSerialization.jsonObject(with: jsonData, options: .allowFragments) as? [String: Any]
            }
        } catch {
            completion(.failure(FunctionsServiceError.encodingError(underlyingError: error)))
            return
        }

        functions.httpsCallable(name).call(dictData) { result, error in
            if let error = error {
                completion(.failure(self.mapFirebaseError(error, forFunction: name)))
                return
            }

            guard let resultData = result?.data else {
                completion(.failure(FunctionsServiceError.decodingError(
                    underlyingError: NSError(domain: "FirebaseFunctionsService", code: -2, userInfo: [NSLocalizedDescriptionKey: "Function \(name) returned no data."])
                )))
                return
            }

            do {
                // Convert the 'Any' resultData to Data, then decode
                let jsonData = try JSONSerialization.data(withJSONObject: resultData, options: [])
                let decoder = JSONDecoder()
                // Configure decoder if needed (e.g., dateDecodingStrategy)
                let decodedResponse = try decoder.decode(ResponseDTO.self, from: jsonData)
                completion(.success(decodedResponse))
            } catch let decodeError {
                completion(.failure(FunctionsServiceError.decodingError(underlyingError: decodeError)))
            }
        }
    }

    // Type-safe version with [String: Any]? request and Decodable response
    func callFunction<ResponseDTO: Decodable>(
        name: String,
        data: [String: Any]?,
        responseType: ResponseDTO.Type, // Parameter kept for clarity
        completion: @escaping (Result<ResponseDTO, Error>) -> Void
    ) {
         functions.httpsCallable(name).call(data) { result, error in
            if let error = error {
                completion(.failure(self.mapFirebaseError(error, forFunction: name)))
                return
            }

            guard let resultData = result?.data else {
                completion(.failure(FunctionsServiceError.decodingError(
                    underlyingError: NSError(domain: "FirebaseFunctionsService", code: -2, userInfo: [NSLocalizedDescriptionKey: "Function \(name) returned no data."])
                )))
                return
            }

            do {
                let jsonData = try JSONSerialization.data(withJSONObject: resultData, options: [])
                let decoder = JSONDecoder()
                // Configure decoder if needed
                let decodedResponse = try decoder.decode(ResponseDTO.self, from: jsonData)
                completion(.success(decodedResponse))
            } catch let decodeError {
                completion(.failure(FunctionsServiceError.decodingError(underlyingError: decodeError)))
            }
        }
    }

    private func mapFirebaseError(_ error: Error, forFunction functionName: String) -> FunctionsServiceError {
        let nsError = error as NSError
        if nsError.domain == FunctionsErrorDomain {
            let code = FunctionsErrorCode(rawValue: nsError.code) ?? .unknown
            let message = nsError.userInfo[NSLocalizedDescriptionKey] as? String ?? "An unknown error occurred."
            let details = nsError.userInfo[FunctionsErrorDetailsKey] // This is usually what the function itself throws/returns as error object

            // You could switch on 'code' for more specific errors if needed
            // e.g., .notFound, .unauthenticated, .permissionDenied
            return .functionError(name: functionName, message: message, details: details)
        } else if (nsError.domain == NSURLErrorDomain) {
             return .networkError(underlyingError: error)
        }
        return .unknownError(underlyingError: error)
    }
}
