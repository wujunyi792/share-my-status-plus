//
//  ClientResourceService.swift
//  share-my-status-client
//

import Foundation

actor ClientResourceService {
    private let logger = AppLogger.app
    private let session: URLSession
    private var baseURL: String = ""
    private var secretKey: String = ""

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 20
        config.timeoutIntervalForResource = 40
        self.session = URLSession(configuration: config)

        logger.info("Client resource service initialized")
    }

    func updateConfiguration(endpointURL: String, secretKey: String) {
        self.baseURL = Self.extractBaseURL(from: endpointURL)
        self.secretKey = secretKey
        logger.info("Client resource service configuration updated")
    }

    func fetchResources() async throws -> ClientResources? {
        guard !baseURL.isEmpty, !secretKey.isEmpty else { return nil }
        guard let url = URL(string: "\(baseURL)/api/v1/client/resources") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(secretKey, forHTTPHeaderField: "X-Secret-Key")

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        guard httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        return try JSONDecoder().decode(ClientResources.self, from: data)
    }

    private static func extractBaseURL(from endpointURL: String) -> String {
        guard let url = URL(string: endpointURL),
              var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return endpointURL
        }
        components.path = ""
        components.query = nil
        components.fragment = nil
        return components.url?.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/")) ?? endpointURL
    }
}
