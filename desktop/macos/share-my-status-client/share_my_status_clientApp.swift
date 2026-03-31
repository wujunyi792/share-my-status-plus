//
//  share_my_status_clientApp.swift
//  share-my-status-client
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
                .environmentObject(coordinator)
                // Note: Configuration is already synced in AppCoordinator.init
                // and will auto-update via Combine observer
                .handlesExternalEvents(preferring: Set(arrayLiteral: "main"), allowing: Set(arrayLiteral: "*"))
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)  // Allow user to resize window
        .defaultSize(width: 750, height: 600)  // Larger default size
        .defaultPosition(.center)
        .handlesExternalEvents(matching: Set(arrayLiteral: "main"))
        .commands {
            // Remove "New Window" command to prevent duplicates
            CommandGroup(replacing: .newItem) { }
            CommandGroup(after: .appInfo) {
                Button("检查更新…") {
                    coordinator.checkForUpdates()
                }
                .disabled(!coordinator.canCheckForUpdates)
            }
        }
        
        // MenuBarExtra requires macOS 13.0+
        MenuBarExtra("Share My Status", systemImage: "antenna.radiowaves.left.and.right") {
            MenuBarView()
                .environmentObject(coordinator.configuration)
                .environmentObject(coordinator.reporter)
                .environmentObject(coordinator)
        }
        .menuBarExtraStyle(.window)
    }
}

// App Delegate

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Start as regular app (show in Dock)
        NSApp.setActivationPolicy(.regular)
        
        // Setup window close monitoring
        setupWindowCloseMonitoring()
        
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
            // Find and show the main window
            if let mainWindow = findMainWindow() {
                NSApp.setActivationPolicy(.regular)
                NSApp.activate(ignoringOtherApps: true)
                mainWindow.makeKeyAndOrderFront(nil)
            }
        }
        return true
    }
    
    // Helper: Find main content window
    private func findMainWindow() -> NSWindow? {
        return NSApplication.shared.windows.first { window in
            window.title.contains("Share My Status") && !window.isKind(of: NSPanel.self)
        }
    }
    
    // Setup monitoring for window close events
    private func setupWindowCloseMonitoring() {
        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let window = notification.object as? NSWindow else { 
                print("[Window] Close notification but no window object")
                return 
            }
            
            let className = NSStringFromClass(type(of: window))
            print("[Window] Window closing: \(className), isPanel: \(window.isKind(of: NSPanel.self)), canBecomeKey: \(window.canBecomeKey)")
            
            // Check if this is a regular window (not status bar)
            guard !window.isKind(of: NSPanel.self) && !className.contains("StatusBar") else {
                print("[Window] Ignoring panel/status bar window close")
                return
            }
            
            print("[Window] Main window closing, will hide from Dock after delay")
            
            // Main window closing, switch back to accessory mode after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                // Check if there are any other non-panel windows still open
                let openWindows = NSApplication.shared.windows.filter { w in
                    let wClassName = NSStringFromClass(type(of: w))
                    return w != window && 
                           !w.isKind(of: NSPanel.self) && 
                           !wClassName.contains("StatusBar") &&
                           w.isVisible
                }
                
                print("[Window] Other windows after close: \(openWindows.count)")
                
                if openWindows.isEmpty {
                    print("[Window] No other windows, switching to accessory mode")
                    NSApp.setActivationPolicy(.accessory)
                } else {
                    print("[Window] Other windows still open, keeping regular mode")
                }
            }
        }
    }
}
