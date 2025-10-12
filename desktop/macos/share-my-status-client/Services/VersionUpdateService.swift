//
//  VersionUpdateService.swift
//  share-my-status-client
//

import Foundation

/// Actor-based version update service
actor VersionUpdateService {
    private let logger = AppLogger.app
    private let session: URLSession
    private var baseURL: String = ""
    
    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 20
        config.timeoutIntervalForResource = 40
        self.session = URLSession(configuration: config)
        
        logger.info("VersionUpdateService initialized")
    }
    
    // Configuration
    func updateConfiguration(baseURL: String) {
        // Extract base URL from endpoint (remove path if present)
        if let url = URL(string: baseURL) {
            var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            components?.path = ""
            self.baseURL = components?.url?.absoluteString ?? baseURL
        } else {
            self.baseURL = baseURL
        }
        logger.info("Version update service configuration updated")
    }
    
    // Check for updates
    func checkForUpdates(platform: String = "macos", version: String, build: Int32) async throws -> ClientVersionInfo? {
        guard !baseURL.isEmpty else { return nil }
        guard var components = URLComponents(string: "\(baseURL)/api/v1/client/check-version") else {
            throw URLError(.badURL)
        }
        components.queryItems = [
            URLQueryItem(name: "platform", value: platform),
            URLQueryItem(name: "version", value: version),
            URLQueryItem(name: "build", value: String(build))
        ]
        guard let url = components.url else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        guard httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        let decoder = JSONDecoder()
        let resp = try decoder.decode(CheckClientVersionResponse.self, from: data)
        
        if let latest = resp.latest {
            logger.info("Update available: \(latest.version ?? "") (\(latest.buildNumber ?? 0))")
            return latest
        } else {
            logger.info("No update available")
            return nil
        }
    }
}