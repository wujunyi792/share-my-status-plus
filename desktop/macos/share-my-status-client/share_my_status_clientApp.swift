//
//  share_my_status_clientApp.swift
//  share-my-status-client
//
//  Refactored on 2025-01-07.
//

import SwiftUI

@main
struct share_my_status_clientApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    // Use AppCoordinator as single source of truth
    @StateObject private var coordinator = AppCoordinator.shared
    
    var body: some Scene {
        WindowGroup(id: "main") {
            ContentView()
                .environmentObject(coordinator.configuration)
                .environmentObject(coordinator.reporter)
                .onAppear {
                    coordinator.reporter.updateConfiguration(coordinator.configuration)
                }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultPosition(.center)
        
        // MenuBarExtra requires macOS 13.0+
        if #available(macOS 13.0, *) {
            MenuBarExtra("Share My Status", systemImage: "antenna.radiowaves.left.and.right") {
                MenuBarView()
                    .environmentObject(coordinator.configuration)
                    .environmentObject(coordinator.reporter)
            }
            .menuBarExtraStyle(.window)
        }
    }
}

// MARK: - App Delegate

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide Dock icon, show only in status bar
        NSApp.setActivationPolicy(.accessory)
        
        // Notify coordinator
        Task { @MainActor in
            AppCoordinator.shared.applicationDidFinishLaunching()
        }
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        // Notify coordinator
        Task { @MainActor in
            AppCoordinator.shared.applicationWillTerminate()
        }
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // Show main window when Dock icon is clicked
        if !flag {
            for window in sender.windows {
                window.makeKeyAndOrderFront(nil)
            }
        }
        return true
    }
}

