import Foundation

enum BackendAPIError: LocalizedError {
    case invalidResponse
    case server(String)
    case transport(Error)
    case emptyData

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid backend response."
        case .server(let message):
            return message
        case .transport(let error):
            return error.localizedDescription
        case .emptyData:
            return "The backend returned an empty response."
        }
    }
}

@MainActor
final class BackendAPIClient {
    static let shared = BackendAPIClient()

    private let session: URLSession
    private let baseURL = URL(string: "http://127.0.0.1:8765/api")!
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    init(session: URLSession = .shared) {
        self.session = session
    }

    func healthCheck() async throws -> HealthResponse {
        try await request(path: "health", method: "GET", body: Optional<String>.none)
    }

    func startMonitor(payload: StartMonitorPayload) async throws -> BackendMessageResponse {
        try await request(path: "start_monitor", method: "POST", body: payload)
    }

    func pauseMonitor() async throws -> BackendMessageResponse {
        try await request(path: "pause_monitor", method: "POST", body: Optional<String>.none)
    }

    func resumeMonitor() async throws -> BackendMessageResponse {
        try await request(path: "resume_monitor", method: "POST", body: Optional<String>.none)
    }

    func stopMonitor() async throws -> StopMonitorResponse {
        try await request(path: "stop_monitor", method: "POST", body: Optional<String>.none)
    }

    func getSettings() async throws -> SettingsResponse {
        try await request(path: "settings", method: "GET", body: Optional<String>.none)
    }

    func saveSettings(content: String) async throws -> BackendMessageResponse {
        struct Payload: Encodable {
            let content: String
        }

        return try await request(path: "settings", method: "POST", body: Payload(content: content))
    }

    func getCiteFiles() async throws -> CiteFilesResponse {
        try await request(path: "cite_files", method: "GET", body: Optional<String>.none)
    }

    func catchup() async throws -> CatchupResponse {
        try await request(path: "catchup", method: "POST", body: Optional<String>.none)
    }

    func catchupChat(payload: CatchupChatRequest) async throws -> CatchupChatResponse {
        try await request(path: "catchup_chat", method: "POST", body: payload)
    }

    func emergencyRescue() async throws -> RescueResponse {
        try await request(path: "emergency_rescue", method: "POST", body: Optional<String>.none)
    }

    func emergencyRescueChat(payload: RescueChatRequest) async throws -> RescueChatResponse {
        try await request(path: "emergency_rescue_chat", method: "POST", body: payload)
    }

    private func request<Response: Decodable, Body: Encodable>(
        path: String,
        method: String,
        body: Body?
    ) async throws -> Response {
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = method

        if let body {
            request.httpBody = try encoder.encode(body)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        let (data, response) = try await perform(request: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw BackendAPIError.invalidResponse
        }

        guard 200..<300 ~= httpResponse.statusCode else {
            let message = Self.decodeServerMessage(from: data) ?? HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode)
            throw BackendAPIError.server(message)
        }

        guard !data.isEmpty else {
            throw BackendAPIError.emptyData
        }

        return try decoder.decode(Response.self, from: data)
    }

    private func perform(request: URLRequest) async throws -> (Data, URLResponse) {
        try await withCheckedThrowingContinuation { continuation in
            let task = session.dataTask(with: request) { data, response, error in
                if let error {
                    continuation.resume(throwing: BackendAPIError.transport(error))
                    return
                }

                guard let response else {
                    continuation.resume(throwing: BackendAPIError.invalidResponse)
                    return
                }

                continuation.resume(returning: (data ?? Data(), response))
            }
            task.resume()
        }
    }

    private static func decodeServerMessage(from data: Data) -> String? {
        guard !data.isEmpty else {
            return nil
        }

        if let decoded = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let detail = decoded["detail"] as? String {
                return detail
            }
            if let message = decoded["message"] as? String {
                return message
            }
        }

        return String(data: data, encoding: .utf8)
    }
}
