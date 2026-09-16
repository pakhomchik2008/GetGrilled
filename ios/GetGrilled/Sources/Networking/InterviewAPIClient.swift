import Foundation

enum APIError: LocalizedError {
    case invalidResponse
    case server(status: Int, body: String)
    case decoding

    /// Backend error endpoints return `{"error": "..."}` — surface that message directly
    /// instead of a generic "operation couldn't be completed" string.
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from server."
        case .server(let status, let body):
            struct ErrorBody: Decodable { let error: String }
            if let data = body.data(using: .utf8), let decoded = try? JSONDecoder().decode(ErrorBody.self, from: data) {
                return decoded.error
            }
            return "Server error (\(status))."
        case .decoding:
            return "Couldn't read the server's response."
        }
    }
}

/// Stream events emitted by the interviewer chat endpoints, one per SSE `data:` line.
enum ChatStreamEvent: Decodable {
    case delta(text: String)
    case done(sessionId: String)

    private enum CodingKeys: String, CodingKey {
        case type, text, sessionId
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "delta":
            self = .delta(text: try container.decode(String.self, forKey: .text))
        case "done":
            self = .done(sessionId: try container.decode(String.self, forKey: .sessionId))
        default:
            throw APIError.decoding
        }
    }
}

/// Talks to the Vercel API layer. Never calls Supabase or the LLM directly.
struct InterviewAPIClient {
    private let session = URLSession(configuration: .default)

    private func authorizedRequest(path: String, body: some Encodable) async throws -> URLRequest {
        var request = URLRequest(url: Config.apiBaseURL.appendingPathComponent(path))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let token = try await SupabaseAuthProvider.shared.accessToken()
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(body)
        return request
    }

    private func streamEvents(for request: URLRequest) -> AsyncThrowingStream<ChatStreamEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let (bytes, response) = try await session.bytes(for: request)
                    guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
                        let status = (response as? HTTPURLResponse)?.statusCode ?? -1
                        continuation.finish(throwing: APIError.server(status: status, body: ""))
                        return
                    }
                    for try await line in bytes.lines {
                        guard line.hasPrefix("data: ") else { continue }
                        let payload = String(line.dropFirst("data: ".count))
                        guard let data = payload.data(using: .utf8) else { continue }
                        let event = try JSONDecoder().decode(ChatStreamEvent.self, from: data)
                        continuation.yield(event)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    struct StartRequestBody: Encodable {
        let difficulty: Difficulty
    }

    func startInterview(difficulty: Difficulty) async throws -> AsyncThrowingStream<ChatStreamEvent, Error> {
        let request = try await authorizedRequest(path: "api/interview/start", body: StartRequestBody(difficulty: difficulty))
        return streamEvents(for: request)
    }

    struct MessageRequestBody: Encodable {
        let sessionId: String
        let content: String
    }

    func sendMessage(sessionId: String, content: String) async throws -> AsyncThrowingStream<ChatStreamEvent, Error> {
        let request = try await authorizedRequest(path: "api/interview/message", body: MessageRequestBody(sessionId: sessionId, content: content))
        return streamEvents(for: request)
    }

    struct FinishRequestBody: Encodable {
        let sessionId: String
    }

    func finishInterview(sessionId: String) async throws -> SessionFeedback {
        let request = try await authorizedRequest(path: "api/interview/finish", body: FinishRequestBody(sessionId: sessionId))
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw APIError.server(status: status, body: String(data: data, encoding: .utf8) ?? "")
        }
        return try JSONDecoder().decode(SessionFeedback.self, from: data)
    }
}
