//
//  SparkleUpdater.swift
//  share-my-status-client
//
//  Wraps Sparkle's SPUStandardUpdaterController for use from SwiftUI.
//  The feed URL and EdDSA public key are read from Info.plist
//  (SUFeedURL / SUPublicEDKey). Updates are signed in CI with the
//  matching private key, so only authentic releases are installed.
//

import Foundation
import Combine
import SwiftUI
import Sparkle

struct SparkleUpdateInfo {
    let title: String
    let displayVersion: String
    let buildVersion: String
}

/// Observable wrapper around Sparkle's updater controller.
///
/// Holds a single `SPUStandardUpdaterController` for the app lifetime and
/// publishes `canCheckForUpdates` so menu items can disable themselves while
/// a check is already in flight.
@MainActor
final class SparkleUpdater: NSObject, ObservableObject, SPUUpdaterDelegate, SPUStandardUserDriverDelegate {
    /// Shared instance, started once at launch.
    static let shared = SparkleUpdater()

    /// The standard controller manages the updater and the user-facing UI.
    /// `startingUpdater: true` begins the scheduled background check cycle.
    private var controller: SPUStandardUpdaterController!

    /// Drives the enabled state of "Check for Updates…" menu items.
    @Published var canCheckForUpdates = false
    @Published var availableUpdate: SparkleUpdateInfo?

    private let logger = AppLogger.app

    private override init() {
        super.init()

        controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: self,
            userDriverDelegate: self
        )

        // Mirror Sparkle's KVO-backed property onto our @Published one.
        controller.updater
            .publisher(for: \.canCheckForUpdates)
            .receive(on: RunLoop.main)
            .assign(to: &$canCheckForUpdates)
    }

    /// Trigger a user-initiated update check (shows Sparkle's UI).
    func checkForUpdates() {
        controller.updater.checkForUpdates()
    }

    /// Force one launch-time background check so users see fresh releases promptly.
    ///
    /// Sparkle's scheduler otherwise waits for `SUScheduledCheckInterval`, which means
    /// a user can miss a just-published update until the next scheduled check.
    func checkForUpdatesInBackgroundOnLaunch() {
        guard controller.updater.automaticallyChecksForUpdates else {
            logger.info("Sparkle automatic checks are disabled")
            return
        }
        guard !controller.updater.sessionInProgress else {
            logger.info("Sparkle update session already in progress")
            return
        }

        logger.info("Checking for Sparkle update information on launch")
        controller.updater.checkForUpdateInformation()
    }

    func standardUserDriverShouldHandleShowingScheduledUpdate(_ update: SUAppcastItem, andInImmediateFocus immediateFocus: Bool) -> Bool {
        // Keep Sparkle's standard scheduled update UI. The in-app banner below is
        // supplemental, so users still see a persistent hint if the popup is delayed.
        return true
    }

    func standardUserDriverWillHandleShowingUpdate(_ handleShowingUpdate: Bool, forUpdate update: SUAppcastItem, state: SPUUserUpdateState) {
        rememberAvailableUpdate(update)
    }

    func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        rememberAvailableUpdate(item)
    }

    func updaterDidNotFindUpdate(_ updater: SPUUpdater, error: Error) {
        availableUpdate = nil
    }

    private func rememberAvailableUpdate(_ item: SUAppcastItem) {
        let title = item.title ?? "发现新版本"
        availableUpdate = SparkleUpdateInfo(
            title: title,
            displayVersion: item.displayVersionString,
            buildVersion: item.versionString
        )
        logger.info("Sparkle update available: \(item.displayVersionString) (\(item.versionString))")
    }
}

/// A "Check for Updates…" button bound to the shared updater.
///
/// Reusable in both the app's main menu (`.commands`) and the MenuBarExtra menu.
struct CheckForUpdatesView: View {
    @ObservedObject private var updater = SparkleUpdater.shared

    var body: some View {
        Button("检查更新…") {
            updater.checkForUpdates()
        }
        .disabled(!updater.canCheckForUpdates)
    }
}
