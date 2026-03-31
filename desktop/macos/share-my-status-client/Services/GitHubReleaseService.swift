//
//  GitHubReleaseService.swift
//  share-my-status-client
//

import Foundation

actor GitHubReleaseService {
    private let logger = AppLogger.app

    static let repoOwner = "wujunyi792"
    static let repoName = "share-my-status-plus"
    static let tagPrefix = "desktop-macos-v"

    private let session: URLSession

    init() {
        self.session = URLSession(configuration: .default)
        logger.info("GitHubReleaseService initialized")
    }

    // MARK: - Check for updates

    func checkForUpdate() async throws -> GitHubReleaseInfo? {
        let currentVersion = await AppVersionUtility.appVersion
        let currentBuild = await AppVersionUtility.buildNumber

        guard let current = ParsedVersion.parse(version: currentVersion, build: currentBuild) else {
            logger.error("Cannot parse current app version: \(currentVersion) (\(currentBuild))")
            return nil
        }

        let release = try await fetchLatestRelease()
        guard let release else { return nil }

        guard let remoteVersion = ParsedVersion.parseFromTag(release.tagName) else {
            logger.warning("Cannot parse remote tag: \(release.tagName)")
            return nil
        }

        guard remoteVersion > current else {
            logger.info("Current \(currentVersion)(\(currentBuild)) is up to date (remote: \(release.tagName))")
            return nil
        }

        guard let zipAsset = release.assets.first(where: { $0.name.hasSuffix(".zip") }) else {
            logger.warning("No .zip asset found in release \(release.tagName)")
            return nil
        }

        guard let downloadURL = URL(string: zipAsset.browserDownloadUrl) else {
            logger.warning("Invalid download URL: \(zipAsset.browserDownloadUrl)")
            return nil
        }

        let versionStr = extractVersion(from: release.tagName)
        let buildStr = extractBuild(from: release.tagName)

        let info = GitHubReleaseInfo(
            tagName: release.tagName,
            version: versionStr,
            buildNumber: buildStr,
            releaseNotes: release.body,
            downloadURL: downloadURL,
            assetSize: zipAsset.size,
            publishedAt: release.publishedAt
        )

        logger.info("Update available: \(info.version) (\(info.buildNumber))")
        return info
    }

    // MARK: - Download

    func downloadUpdate(info: GitHubReleaseInfo, onProgress: @escaping @Sendable (Double) -> Void) async throws -> URL {
        let delegate = DownloadDelegate(onProgress: onProgress)
        let delegateSession = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)

        defer { delegateSession.invalidateAndCancel() }

        var request = URLRequest(url: info.downloadURL)
        request.setValue("application/octet-stream", forHTTPHeaderField: "Accept")

        let (tempURL, response) = try await delegateSession.download(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw UpdateError.downloadFailed("HTTP \((response as? HTTPURLResponse)?.statusCode ?? 0)")
        }

        let dest = FileManager.default.temporaryDirectory
            .appendingPathComponent("ShareMyStatus_update_\(info.tagName).zip")
        try? FileManager.default.removeItem(at: dest)
        try FileManager.default.moveItem(at: tempURL, to: dest)

        logger.info("Downloaded update to \(dest.path)")
        return dest
    }

    // MARK: - Install

    func installUpdate(zipURL: URL) async throws {
        guard let appBundlePath = Bundle.main.bundlePath as String? else {
            throw UpdateError.installFailed("Cannot determine app bundle path")
        }

        let appURL = URL(fileURLWithPath: appBundlePath)
        let appParent = appURL.deletingLastPathComponent()
        let appName = appURL.lastPathComponent

        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ShareMyStatus_install_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }

        let (output, exitCode) = try await Process.runAsync(
            launchPath: "/usr/bin/ditto",
            arguments: ["-xk", zipURL.path, tempDir.path],
            timeout: 120
        )

        guard exitCode == 0 else {
            let errMsg = String(data: output, encoding: .utf8) ?? "unknown"
            throw UpdateError.installFailed("Unzip failed (\(exitCode)): \(errMsg)")
        }

        let extractedApp = try findApp(in: tempDir)

        let backup = appParent.appendingPathComponent(".\(appName).backup")
        try? FileManager.default.removeItem(at: backup)

        try FileManager.default.moveItem(at: appURL, to: backup)

        do {
            try FileManager.default.moveItem(at: extractedApp, to: appURL)
        } catch {
            try? FileManager.default.moveItem(at: backup, to: appURL)
            throw UpdateError.installFailed("Replace failed: \(error.localizedDescription)")
        }

        try? FileManager.default.removeItem(at: backup)
        try? FileManager.default.removeItem(at: zipURL)

        logger.info("App replaced successfully, launching new version...")
        relaunchApp(at: appURL)
    }

    // MARK: - Private

    private func fetchLatestRelease() async throws -> GitHubRelease? {
        let urlStr = "https://api.github.com/repos/\(Self.repoOwner)/\(Self.repoName)/releases"
        guard let url = URL(string: urlStr) else { throw UpdateError.invalidURL }

        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        request.timeoutInterval = 30

        let (data, response) = try await session.data(for: request)

        guard let httpResp = response as? HTTPURLResponse, httpResp.statusCode == 200 else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            throw UpdateError.apiFailed("GitHub API returned \(code)")
        }

        let releases = try JSONDecoder().decode([GitHubRelease].self, from: data)

        return releases
            .filter { !$0.draft && !$0.prerelease && $0.tagName.hasPrefix(Self.tagPrefix) }
            .sorted { lhs, rhs in
                guard let lv = ParsedVersion.parseFromTag(lhs.tagName),
                      let rv = ParsedVersion.parseFromTag(rhs.tagName) else { return false }
                return lv > rv
            }
            .first
    }

    private func extractVersion(from tag: String) -> String {
        let prefix = Self.tagPrefix
        guard tag.hasPrefix(prefix) else { return tag }
        let rest = String(tag.dropFirst(prefix.count))
        return String(rest.split(separator: "-").first ?? Substring(rest))
    }

    private func extractBuild(from tag: String) -> String {
        let prefix = Self.tagPrefix
        guard tag.hasPrefix(prefix) else { return "0" }
        let rest = String(tag.dropFirst(prefix.count))
        let parts = rest.split(separator: "-")
        return parts.count > 1 ? String(parts.last!) : "0"
    }

    private func findApp(in directory: URL) throws -> URL {
        let contents = try FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: nil)

        if let app = contents.first(where: { $0.pathExtension == "app" }) {
            return app
        }

        for item in contents {
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: item.path, isDirectory: &isDir), isDir.boolValue {
                if let app = try? findApp(in: item) {
                    return app
                }
            }
        }

        throw UpdateError.installFailed("No .app found in downloaded archive")
    }

    nonisolated private func relaunchApp(at appURL: URL) {
        let script = "sleep 1; open \"\(appURL.path)\""

        let process = Process()
        process.launchPath = "/bin/bash"
        process.arguments = ["-c", script]
        try? process.run()

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 500_000_000)
            NSApplication.shared.terminate(nil)
        }
    }
}

// MARK: - Download Delegate

private final class DownloadDelegate: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    let onProgress: @Sendable (Double) -> Void

    init(onProgress: @escaping @Sendable (Double) -> Void) {
        self.onProgress = onProgress
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                    didWriteData bytesWritten: Int64,
                    totalBytesWritten: Int64,
                    totalBytesExpectedToWrite: Int64) {
        guard totalBytesExpectedToWrite > 0 else { return }
        let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        onProgress(progress)
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                    didFinishDownloadingTo location: URL) {
        // handled by async download(for:)
    }
}

// MARK: - Errors

enum UpdateError: LocalizedError, Sendable {
    case invalidURL
    case apiFailed(String)
    case downloadFailed(String)
    case installFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "无效的更新地址"
        case .apiFailed(let msg): return "GitHub API 请求失败: \(msg)"
        case .downloadFailed(let msg): return "下载失败: \(msg)"
        case .installFailed(let msg): return "安装失败: \(msg)"
        }
    }
}
