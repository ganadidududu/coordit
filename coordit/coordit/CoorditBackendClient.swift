import Foundation

#if os(iOS)
enum CoorditBackendConfig {
    static func baseURL(arguments: [String] = ProcessInfo.processInfo.arguments) -> URL {
        if
            let markerIndex = arguments.firstIndex(of: "--coordit-api-base-url"),
            arguments.indices.contains(arguments.index(after: markerIndex)),
            let url = URL(string: arguments[arguments.index(after: markerIndex)])
        {
            return url
        }

        if
            let saved = UserDefaults.standard.string(forKey: "coordit.apiBaseURL"),
            let url = URL(string: saved)
        {
            return url
        }

        return URL(string: "http://localhost:4000")!
    }
}

enum CoorditBackendClientError: LocalizedError {
    case invalidResponse
    case server(statusCode: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            "백엔드 응답을 읽을 수 없어요."
        case .server(_, let message):
            message
        }
    }
}

struct CoorditBackendClient {
    let baseURL: URL
    var session: URLSession = .shared

    func health() async throws -> CoorditBackendHealth {
        try await send(path: "/health", method: "GET", token: nil, body: Optional<String>.none)
    }

    func login(email: String, password: String) async throws -> CoorditAuthSession {
        try await send(path: "/auth/login", method: "POST", token: nil, body: AuthRequest(email: email, password: password))
    }

    func signup(email: String, password: String) async throws -> CoorditAuthSession {
        try await send(path: "/auth/signup", method: "POST", token: nil, body: AuthRequest(email: email, password: password))
    }

    func me(token: String) async throws -> CoorditUserProfile {
        try await send(path: "/users/me", method: "GET", token: token, body: Optional<String>.none)
    }

    func updateMe(token: String, displayName: String) async throws -> CoorditUserProfile {
        try await send(path: "/users/me", method: "PATCH", token: token, body: UpdateProfileRequest(displayName: displayName))
    }

    func listBodyMeasurements(token: String) async throws -> [CoorditBodyMeasurement] {
        try await send(path: "/body-measurements", method: "GET", token: token, body: Optional<String>.none)
    }

    func createBodyMeasurement(token: String, request: BodyMeasurementRequest) async throws -> CoorditBodyMeasurement {
        try await send(path: "/body-measurements", method: "POST", token: token, body: request)
    }

    private func send<ResponseBody: Decodable, RequestBody: Encodable>(
        path: String,
        method: String,
        token: String?,
        body: RequestBody?
    ) async throws -> ResponseBody {
        var request = URLRequest(url: baseURL.appending(path: path))
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(body)
        }

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw CoorditBackendClientError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let apiError = try? JSONDecoder().decode(CoorditBackendErrorResponse.self, from: data)
            throw CoorditBackendClientError.server(
                statusCode: httpResponse.statusCode,
                message: apiError?.message ?? "백엔드 요청에 실패했어요."
            )
        }

        return try JSONDecoder().decode(ResponseBody.self, from: data)
    }
}

private struct AuthRequest: Encodable {
    let email: String
    let password: String
}

private struct UpdateProfileRequest: Encodable {
    let displayName: String
}

struct BodyMeasurementRequest: Encodable {
    let shoulderWidth: Double?
    let chestCircumference: Double?
    let waistCircumference: Double?
    let hipCircumference: Double?
    let rawData: RawData

    struct RawData: Encodable {
        let source: String
        let inseamCm: Double?
    }
}
#endif
