import Foundation

/// Talks to the v2 round/plan endpoints. Same auth + SSE pattern as InterviewAPIClient.
struct RoundAPIClient {
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

    private func decodedResponse<T: Decodable>(for request: URLRequest, as type: T.Type) async throws -> T {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw APIError.server(status: status, body: String(data: data, encoding: .utf8) ?? "")
        }
        return try JSONDecoder().decode(T.self, from: data)
    }

    private func streamEvents(for request: URLRequest) -> AsyncThrowingStream<ChatStreamEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let (bytes, response) = try await session.bytes(for: request)
                    guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
                        let status = (response as? HTTPURLResponse)?.statusCode ?? -1
                        var body = ""
                        for try await line in bytes.lines { body += line }
                        continuation.finish(throwing: APIError.server(status: status, body: body))
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

    // MARK: Session

    struct CreateSessionBody: Encodable {
        let mode: SessionMode
        let roleTitle: String
        let seniority: Seniority
        let focusNotes: String?
        let planStageId: String?
        let jobContext: String?
    }

    func createSession(
        mode: SessionMode,
        roleTitle: String,
        seniority: Seniority,
        focusNotes: String?,
        planStageId: String? = nil,
        jobContext: String? = nil
    ) async throws -> CreateSessionResponse {
        let request = try await authorizedRequest(
            path: "api/session/create",
            body: CreateSessionBody(mode: mode, roleTitle: roleTitle, seniority: seniority, focusNotes: focusNotes, planStageId: planStageId, jobContext: jobContext)
        )
        return try await decodedResponse(for: request, as: CreateSessionResponse.self)
    }

    struct SessionIdBody: Encodable {
        let sessionId: String
    }

    func finishSession(sessionId: String) async throws -> SessionFinishResponse {
        let request = try await authorizedRequest(path: "api/session/finish", body: SessionIdBody(sessionId: sessionId))
        return try await decodedResponse(for: request, as: SessionFinishResponse.self)
    }

    // MARK: Round

    struct SessionRoundBody: Encodable {
        let sessionId: String
        let roundId: String
    }

    func startRound(sessionId: String, roundId: String) async throws -> AsyncThrowingStream<ChatStreamEvent, Error> {
        let request = try await authorizedRequest(path: "api/round/start", body: SessionRoundBody(sessionId: sessionId, roundId: roundId))
        return streamEvents(for: request)
    }

    func sendRoundMessage(
        sessionId: String,
        roundId: String,
        content: String,
        action: ChipAction? = nil,
        imageBase64: String? = nil,
        imageMediaType: String? = nil
    ) async throws -> AsyncThrowingStream<ChatStreamEvent, Error> {
        struct Body: Encodable {
            let sessionId: String
            let roundId: String
            let content: String?
            let action: String?
            let imageBase64: String?
            let imageMediaType: String?
        }
        let request = try await authorizedRequest(
            path: "api/round/message",
            body: Body(
                sessionId: sessionId,
                roundId: roundId,
                content: action == nil ? content : nil,
                action: action?.rawValue,
                imageBase64: action == nil ? imageBase64 : nil,
                imageMediaType: action == nil ? imageMediaType : nil
            )
        )
        return streamEvents(for: request)
    }

    func finishRound(sessionId: String, roundId: String, selfEval: SelfEval?, skip: Bool = false) async throws -> RoundFinishResponse {
        struct Body: Encodable {
            let sessionId: String
            let roundId: String
            let selfEval: SelfEval?
            let skip: Bool
        }
        let request = try await authorizedRequest(
            path: "api/round/finish",
            body: Body(sessionId: sessionId, roundId: roundId, selfEval: selfEval, skip: skip)
        )
        return try await decodedResponse(for: request, as: RoundFinishResponse.self)
    }

    // MARK: Plans

    struct GeneratePlanBody: Encodable {
        let roleTitle: String
        let seniority: Seniority
        let companyContext: String?
        let focusNotes: String?
    }

    struct GeneratePlanResponse: Codable {
        struct Stage: Codable {
            let order: Int
            let title: String
            let focus_description: String
        }
        let planId: String
        let stages: [Stage]
    }

    func generatePlan(roleTitle: String, seniority: Seniority, companyContext: String?, focusNotes: String?) async throws -> GeneratePlanResponse {
        let request = try await authorizedRequest(
            path: "api/plans/generate",
            body: GeneratePlanBody(roleTitle: roleTitle, seniority: seniority, companyContext: companyContext, focusNotes: focusNotes)
        )
        return try await decodedResponse(for: request, as: GeneratePlanResponse.self)
    }

    // MARK: Debug (remove before App Store submission — see grant-unlimited.ts)

    struct DebugSubscriptionBody: Encodable {
        let status: String
    }
    struct DebugSubscriptionResponse: Decodable {
        let subscriptionStatus: String
    }

    @discardableResult
    func debugSetSubscription(paid: Bool) async throws -> DebugSubscriptionResponse {
        let request = try await authorizedRequest(
            path: "api/debug/grant-unlimited",
            body: DebugSubscriptionBody(status: paid ? "paid" : "free")
        )
        return try await decodedResponse(for: request, as: DebugSubscriptionResponse.self)
    }
}
