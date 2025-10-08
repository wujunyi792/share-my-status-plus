//
//  NetworkService.swift
//  share-my-status-client
//
//  Created by Refactor on 2025-01-07.
//

import Foundation
import Network

/// Actor-based network service for thread-safe API communication
actor NetworkService {
    // MARK: - Properties
    private let logger = AppLogger.network
    private let session: URLSession
    private let monitor: NWPathMonitor
    private let monitorQueue = DispatchQueue(label: "com.sharemystatus.network.monitor")
    
    private var isConnected = false
    private var endpointURL: String = ""
    private var secretKey: String = ""
    
    // MARK: - Statistics
    private var lastReportTime: Date?
    private var reportCount = 0
    
    // MARK: - Initialization
    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: config)
        
        self.monitor = NWPathMonitor()
        
        // Setup network monitoring
        monitor.pathUpdateHandler = { [weak self] path in
            Task { [weak self] in
                await self?.updateConnectionStatus(path.status == .satisfied)
            }
        }
        monitor.start(queue: monitorQueue)
        
        logger.info("NetworkService initialized")
    }
    
    deinit {
        monitor.cancel()
    }
    
    // MARK: - Configuration
    func updateConfiguration(endpointURL: String, secretKey: String) {
        self.endpointURL = endpointURL
        self.secretKey = secretKey
        logger.info("Network configuration updated")
    }
    
    private func updateConnectionStatus(_ connected: Bool) {
        isConnected = connected
        logger.info("Network status: \(connected ? "Connected" : "Disconnected")")
    }
    
    // MARK: - Report Status
    func reportStatus(_ request: BatchReportRequest) async throws -> BatchReportResponse {
        guard isConnected else {
            throw NetworkError.notConnected
        }
        
        guard !endpointURL.isEmpty, !secretKey.isEmpty else {
            throw NetworkError.invalidConfiguration
        }
        
        guard let url = URL(string: endpointURL) else {
            throw NetworkError.invalidURL
        }
        
        logger.debug("Reporting \(request.events.count) event(s)...")
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue(secretKey, forHTTPHeaderField: "X-Secret-Key")
        
        // Add user agent
        let userAgent = "ShareMyStatus-macOS/1.0 (macOS \(ProcessInfo.processInfo.operatingSystemVersionString))"
        urlRequest.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        
        // Encode request - use camelCase to match Thrift definitions
        let encoder = JSONEncoder()
        urlRequest.httpBody = try encoder.encode(request)
        
        // Send request
        let (data, response) = try await session.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        // Handle status codes
        switch httpResponse.statusCode {
        case 200...299:
            // Decode response - use camelCase to match Thrift definitions
            let decoder = JSONDecoder()
            let batchResponse = try decoder.decode(BatchReportResponse.self, from: data)
            
            lastReportTime = Date()
            reportCount += request.events.count
            
            logger.debug("Report successful: accepted=\(batchResponse.accepted ?? 0), deduped=\(batchResponse.deduped ?? 0)")
            return batchResponse
            
        case 401:
            throw NetworkError.unauthorized
        case 429:
            throw NetworkError.rateLimitExceeded
        default:
            throw NetworkError.httpError(httpResponse.statusCode)
        }
    }
    
    // MARK: - Statistics
    func getStatistics() -> (lastReportTime: Date?, reportCount: Int, isConnected: Bool) {
        return (lastReportTime, reportCount, isConnected)
    }
    
    func getConnectionStatus() -> Bool {
        return isConnected
    }
}

// MARK: - Network Errors

enum NetworkError: LocalizedError {
    case notConnected
    case invalidConfiguration
    case invalidURL
    case invalidResponse
    case unauthorized
    case rateLimitExceeded
    case httpError(Int)
    case encodingFailed
    
    var errorDescription: String? {
        switch self {
        case .notConnected:
            return "网络未连接"
        case .invalidConfiguration:
            return "配置无效"
        case .invalidURL:
            return "无效的URL"
        case .invalidResponse:
            return "无效的响应"
        case .unauthorized:
            return "认证失败"
        case .rateLimitExceeded:
            return "请求过于频繁"
        case .httpError(let code):
            return "HTTP错误: \(code)"
        case .encodingFailed:
            return "编码失败"
        }
    }
}

