//
//  GitHubReleaseModels.swift
//  share-my-status-client
//

import Foundation

struct GitHubRelease: Codable, Sendable {
    let id: Int
    let tagName: String
    let name: String?
    let body: String?
    let draft: Bool
    let prerelease: Bool
    let publishedAt: String?
    let assets: [GitHubAsset]

    enum CodingKeys: String, CodingKey {
        case id
        case tagName = "tag_name"
        case name
        case body
        case draft
        case prerelease
        case publishedAt = "published_at"
        case assets
    }
}

struct GitHubAsset: Codable, Sendable {
    let id: Int
    let name: String
    let contentType: String
    let size: Int
    let browserDownloadUrl: String

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case contentType = "content_type"
        case size
        case browserDownloadUrl = "browser_download_url"
    }
}

struct ParsedVersion: Comparable, Sendable {
    let major: Int
    let minor: Int
    let patch: Int
    let build: Int

    static func < (lhs: ParsedVersion, rhs: ParsedVersion) -> Bool {
        if lhs.major != rhs.major { return lhs.major < rhs.major }
        if lhs.minor != rhs.minor { return lhs.minor < rhs.minor }
        if lhs.patch != rhs.patch { return lhs.patch < rhs.patch }
        return lhs.build < rhs.build
    }

    static func parse(version: String, build: String) -> ParsedVersion? {
        let parts = version.split(separator: ".").compactMap { Int($0) }
        let buildNum = Int(build) ?? 0
        switch parts.count {
        case 1: return ParsedVersion(major: parts[0], minor: 0, patch: 0, build: buildNum)
        case 2: return ParsedVersion(major: parts[0], minor: parts[1], patch: 0, build: buildNum)
        case 3: return ParsedVersion(major: parts[0], minor: parts[1], patch: parts[2], build: buildNum)
        default: return nil
        }
    }

    /// Parse from a release tag like "desktop-macos-v1.3-1"
    static func parseFromTag(_ tag: String) -> ParsedVersion? {
        let prefix = "desktop-macos-v"
        guard tag.hasPrefix(prefix) else { return nil }
        let versionPart = String(tag.dropFirst(prefix.count))
        let components = versionPart.split(separator: "-")
        guard let versionStr = components.first else { return nil }
        let buildStr = components.count > 1 ? String(components.last!) : "0"
        return parse(version: String(versionStr), build: buildStr)
    }
}

struct GitHubReleaseInfo: Equatable, Sendable {
    let tagName: String
    let version: String
    let buildNumber: String
    let releaseNotes: String?
    let downloadURL: URL
    let assetSize: Int
    let publishedAt: String?

    static func == (lhs: GitHubReleaseInfo, rhs: GitHubReleaseInfo) -> Bool {
        lhs.tagName == rhs.tagName
    }
}

enum AppUpdatePhase: Equatable, Sendable {
    case idle
    case checking
    case available(GitHubReleaseInfo)
    case downloading(GitHubReleaseInfo, progress: Double)
    case downloaded(GitHubReleaseInfo, localURL: URL)
    case installing
    case error(String)
}
