import Foundation

struct HealthResponse: Decodable {
    let status: String
}

struct BackendMessageResponse: Decodable {
    let status: String
    let message: String
}

struct StartMonitorPayload: Encodable {
    let course_name: String
    let cite_filename: String?
}

struct StopMonitorResponse: Decodable {
    struct Summary: Decodable {
        let filename: String
        let course_name: String
    }

    let status: String
    let message: String
    let summary: Summary?
    let summary_error: String?
}

struct AlertMessage: Codable, Identifiable, Equatable {
    let type: String
    let level: String
    let keywords: [String]
    let text: String
    let timestamp: String

    var id: String {
        "\(timestamp)-\(keywords.joined(separator: "-"))"
    }
}

struct CiteFileItem: Decodable, Identifiable, Equatable {
    let filename: String
    let updated_at: String
    let size: Int

    var id: String {
        filename
    }
}

struct CiteFilesResponse: Decodable {
    let status: String
    let items: [CiteFileItem]
}

struct SettingsResponse: Decodable {
    let status: String
    let content: String
    let path: String
}

struct CatchupResponse: Decodable {
    let status: String
    let summary: String
}

struct CatchupChatRequest: Encodable {
    let summary: String
    let question: String
    let history: [ChatMessage]
}

struct CatchupChatResponse: Decodable {
    let status: String
    let answer: String
}

struct RescueResponse: Decodable {
    let status: String
    let context: String
    let question: String
    let answer: String
}

struct RescueChatRequest: Encodable {
    let context: String
    let question: String
    let answer: String
    let followup: String
    let history: [ChatMessage]
}

struct RescueChatResponse: Decodable {
    let status: String
    let answer: String
}

struct ChatMessage: Codable, Equatable, Identifiable {
    let role: String
    let content: String

    var id: String {
        "\(role)-\(content)"
    }
}
