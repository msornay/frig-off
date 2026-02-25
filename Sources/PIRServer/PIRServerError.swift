import Foundation
import Hummingbird

/// Errors raised by the PIR server.
///
/// Conforms to `HTTPResponseError` so Hummingbird maps each error
/// variant to the correct HTTP status code automatically.
enum PIRServerError: Error, HTTPResponseError, CustomStringConvertible {
    case noShardsLoaded(usecase: String)
    case unknownUsecase(name: String)
    case invalidShardIndex(index: Int, count: Int)
    case unsupportedRequestType
    case evaluationKeyNotFound
    case missingEvaluationKey
    case unauthorized(reason: String)
    case badRequest(reason: String)

    var description: String {
        switch self {
        case .noShardsLoaded(let usecase):
            return "No shards loaded for usecase '\(usecase)'"
        case .unknownUsecase(let name):
            return "Unknown usecase '\(name)'"
        case .invalidShardIndex(let index, let count):
            return "Shard index \(index) out of range (0..<\(count))"
        case .unsupportedRequestType:
            return "Unsupported request type (only PIR requests are supported)"
        case .evaluationKeyNotFound:
            return "Evaluation key not found; upload keys first via POST /key"
        case .missingEvaluationKey:
            return "Request must include evaluation key or key metadata"
        case .unauthorized(let reason):
            return "Unauthorized: \(reason)"
        case .badRequest(let reason):
            return "Bad request: \(reason)"
        }
    }

    /// Map errors to appropriate HTTP status codes (HTTPResponseError).
    var status: HTTPResponse.Status {
        switch self {
        case .unauthorized:
            return .unauthorized
        case .badRequest, .unsupportedRequestType, .missingEvaluationKey:
            return .badRequest
        case .unknownUsecase, .invalidShardIndex, .evaluationKeyNotFound:
            return .notFound
        case .noShardsLoaded:
            return .internalServerError
        }
    }
}
