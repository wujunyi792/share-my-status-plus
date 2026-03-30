//
//  CoverService.swift
//  share-my-status-client
//


import Foundation

/// Actor-based cover service for thread-safe cover management
actor CoverService {
    // Properties
    private let logger = AppLogger.cover
    private let session: URLSession
    
    private var baseURL: String = ""
    private var secretKey: String = ""
    
    // Cache for uploaded covers (MD5 -> coverHash), bounded to prevent unbounded growth
    private var uploadedCovers: [String: String] = [:]
    private static let maxCacheEntries = 100
    
    // Initialization
    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: config)
        
        logger.info("CoverService initialized")
    }
    
    // Configuration
    func updateConfiguration(baseURL: String, secretKey: String) {
        // Extract base URL from endpoint (remove /v1/state/report if present)
        if let url = URL(string: baseURL) {
            var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            components?.path = ""
            self.baseURL = components?.url?.absoluteString ?? baseURL
        } else {
            self.baseURL = baseURL
        }
        self.secretKey = secretKey
        logger.info("Cover service configuration updated")
    }
    
    // Check and Upload Cover
    func checkAndUploadCover(artworkData: Data) async throws -> String? {
        let md5 = artworkData.md5Hash
        
        if let cachedHash = uploadedCovers[md5] {
            logger.debug("Cover found in cache: \(cachedHash)")
            return cachedHash
        }
        
        let exists = try await checkCoverExists(md5: md5)
        if exists {
            logger.debug("Cover already exists on server: \(md5)")
            cacheInsert(md5: md5, hash: md5)
            return md5
        }
        
        logger.info("Uploading new cover: \(md5)")
        let coverHash = try await uploadCover(artworkData: artworkData)
        cacheInsert(md5: md5, hash: coverHash)
        
        return coverHash
    }
    
    private func cacheInsert(md5: String, hash: String) {
        if uploadedCovers.count >= Self.maxCacheEntries {
            uploadedCovers.removeAll(keepingCapacity: true)
        }
        uploadedCovers[md5] = hash
    }
    
    // Check Cover Exists
    private func checkCoverExists(md5: String) async throws -> Bool {
        guard let url = URL(string: "\(baseURL)/api/v1/cover/exists?md5=\(md5)") else {
            throw CoverError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(secretKey, forHTTPHeaderField: "X-Secret-Key")
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw CoverError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw CoverError.httpError(httpResponse.statusCode)
        }
        
        // Decode response - use camelCase to match API definitions
        let decoder = JSONDecoder()
        let existsResponse = try decoder.decode(CoverExistsResponse.self, from: data)
        
        return existsResponse.exists ?? false
    }
    
    // Upload Cover
    private func uploadCover(artworkData: Data) async throws -> String {
        guard let url = URL(string: "\(baseURL)/api/v1/cover/upload") else {
            throw CoverError.invalidURL
        }
        
        // Encode to base64
        let base64String = artworkData.base64EncodedString()
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(secretKey, forHTTPHeaderField: "X-Secret-Key")
        
        // Encode request - use camelCase to match API definitions
        let uploadRequest = CoverUploadRequest(b64: base64String)
        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(uploadRequest)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw CoverError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw CoverError.httpError(httpResponse.statusCode)
        }
        
        // Decode response - use camelCase to match API definitions
        let decoder = JSONDecoder()
        let uploadResponse = try decoder.decode(CoverUploadResponse.self, from: data)
        
        guard let coverHash = uploadResponse.coverHash else {
            throw CoverError.uploadFailed
        }
        
        logger.info("Cover uploaded successfully: \(coverHash)")
        return coverHash
    }
    
    // Clear Cache
    func clearCache() {
        uploadedCovers.removeAll()
        logger.info("Cover cache cleared")
    }
}

// Cover Errors

enum CoverError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(Int)
    case uploadFailed
    case checkFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "无效的URL"
        case .invalidResponse:
            return "无效的响应"
        case .httpError(let code):
            return "HTTP错误: \(code)"
        case .uploadFailed:
            return "封面上传失败"
        case .checkFailed:
            return "封面检查失败"
        }
    }
}

