//
//  VersionModels.swift
//  share-my-status-client
//

import Foundation

// Version Check API Models (from version_service.thrift)

struct ClientVersionInfo: Codable {
    let platform: String?
    let version: String?
    let buildNumber: Int32?
    let downloadUrl: String?
    let releaseNote: String?
    let forceUpdate: Bool?
    let latest: Bool?
}

struct CheckClientVersionResponse: Codable {
    let base: BaseResponse
    let latest: ClientVersionInfo?
}