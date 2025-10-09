//
//  CoverModels.swift
//  share-my-status-client
//


import Foundation

// Cover Service API Models (from cover_service.thrift)

/// Cover exists request
struct CoverExistsRequest: Codable {
    let md5: String
}

/// Cover exists response
struct CoverExistsResponse: Codable {
    let base: BaseResponse
    let exists: Bool?
    let coverHash: String?
}

/// Cover upload request
struct CoverUploadRequest: Codable {
    let b64: String  // base64-encoded image data
}

/// Cover upload response
struct CoverUploadResponse: Codable {
    let base: BaseResponse
    let coverHash: String?
}

/// Cover get request
struct CoverGetRequest: Codable {
    let hash: String
    let size: Int32?  // 128, 256, etc.
}

/// Cover get response
struct CoverGetResponse: Codable {
    let base: BaseResponse
    let data: Data?
    let contentType: String?
}

