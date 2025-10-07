//
//  StateModels.swift
//  share-my-status-client
//
//  Created by Refactor on 2025-01-07.
//

import Foundation

// MARK: - State Service API Models (from state_service.thrift)

/// Batch report request
struct BatchReportRequest: Codable {
    let events: [ReportEvent]
}

/// Batch report response
struct BatchReportResponse: Codable {
    let base: BaseResponse
    let accepted: Int32?
    let deduped: Int32?
}

/// Query state request
struct QueryStateRequest: Codable {
    let sharingKey: String
}

/// Query state response
struct QueryStateResponse: Codable {
    let base: BaseResponse
    let snapshot: StatusSnapshot?
}

