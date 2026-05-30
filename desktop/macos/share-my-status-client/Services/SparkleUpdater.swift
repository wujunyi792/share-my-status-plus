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

/// Observable wrapper around Sparkle's updater controller.
///
/// Holds a single `SPUStandardUpdaterController` for the app lifetime and
/// publishes `canCheckForUpdates` so menu items can disable themselves while
/// a check is already in flight.
@MainActor
final class SparkleUpdater: ObservableObject {
    /// Shared instance, started once at launch.
    static let shared = SparkleUpdater()

    /// The standard controller manages the updater and the user-facing UI.
    /// `startingUpdater: true` begins the scheduled background check cycle.
    private let controller: SPUStandardUpdaterController

    /// Drives the enabled state of "Check for Updates…" menu items.
    @Published var canCheckForUpdates = false

    private init() {
        controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
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

