import Foundation

#if os(iOS)
struct CoorditAuthSession: Codable, Equatable {
    let accessToken: String
    let refreshToken: String
    let user: CoorditAuthUser
}

struct CoorditAuthUser: Codable, Equatable {
    let id: String
    let email: String
}

struct CoorditUserProfile: Codable, Equatable {
    let id: String
    let email: String
    let displayName: String?
    let gender: String?
    let birthYear: Int?
    let createdAt: String
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case email
        case displayName = "display_name"
        case gender
        case birthYear = "birth_year"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct CoorditBodyMeasurement: Codable, Equatable {
    let id: String?
    let shoulderWidth: Double?
    let chestCircumference: Double?
    let waistCircumference: Double?
    let hipCircumference: Double?
    let outseam: Double?
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case shoulderWidth = "shoulder_width"
        case chestCircumference = "chest_circumference"
        case waistCircumference = "waist_circumference"
        case hipCircumference = "hip_circumference"
        case outseam
        case createdAt = "created_at"
    }
}

struct CoorditBackendHealth: Codable, Equatable {
    let ok: Bool
    let service: String
}

struct CoorditBackendErrorResponse: Codable, Equatable {
    let message: String
}
#endif
