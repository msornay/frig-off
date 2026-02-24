import Foundation

/// Errors raised by the Privacy Pass implementation.
public enum PrivacyPassError: Error, CustomStringConvertible {
    case invalidTokenRequest
    case invalidToken
    case keyGenerationFailed

    public var description: String {
        switch self {
        case .invalidTokenRequest:
            return "Invalid token request format"
        case .invalidToken:
            return "Invalid token format"
        case .keyGenerationFailed:
            return "RSA key generation failed"
        }
    }
}
