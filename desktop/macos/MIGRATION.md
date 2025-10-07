# Migration Guide - Legacy to Refactored Code

## Overview

This document describes the changes made in the refactoring and how to migrate.

## What Changed

### Architecture

**Before**: MVVM with ObservableObject + DispatchQueue
**After**: Actor-based services + @MainActor coordinators

### File Structure

**Before**:
```
share-my-status-client/
├── MusicExtractor.swift
├── SystemMonitor.swift
├── ActivityDetector.swift
├── NetworkClient.swift
├── StatusReporter.swift
├── Models.swift
├── AppSettings.swift
├── ContentView.swift
└── MenuBarView.swift
```

**After**:
```
share-my-status-client/
├── Models/
│   ├── API/           # API request/response (from IDL)
│   ├── Domain/        # Domain models
│   └── Settings/      # Configuration
├── Services/          # Actor-based services
├── Core/              # Coordinators
├── Views/             # SwiftUI views
└── Utilities/         # Extensions and helpers
```

## Code Migration

### 1. Configuration Access

**Before**:
```swift
@EnvironmentObject var settings: AppSettings
settings.endpointURL
```

**After**:
```swift
@EnvironmentObject var configuration: AppConfiguration
configuration.endpointURL
```

### 2. Status Reporter Access

**Before**:
```swift
@EnvironmentObject var statusReporter: StatusReporter
statusReporter.musicExtractor.currentMusic
```

**After**:
```swift
@EnvironmentObject var reporter: StatusReporter
reporter.currentMusic  // Now directly on reporter
```

### 3. Starting/Stopping Reporting

**Before**:
```swift
statusReporter.startReporting()
statusReporter.stopReporting()
```

**After**:
```swift
reporter.startReporting()
reporter.stopReporting()
```

### 4. Manual Report Trigger

**Before**:
```swift
Task {
    await statusReporter.reportNow()
}
```

**After**:
```swift
Task {
    await reporter.performReport()
}
```

### 5. Getting Current Status

**Before**:
```swift
let music = statusReporter.musicExtractor.currentMusic
let system = statusReporter.systemMonitor.currentSystem
let activity = statusReporter.activityDetector.currentActivity
```

**After**:
```swift
let music = reporter.currentMusic
let system = reporter.currentSystem
let activity = reporter.currentActivity
```

## API Model Changes

### Request Structure

**Before**:
```swift
struct ReportEvent: Codable {
    let version: String = "1"
    let ts: Int64  // Timestamp in event
    let system: SystemInfo?
    let music: MusicInfo?
    let activity: ActivityInfo?
    let idempotencyKey: String
}
```

**After**:
```swift
struct ReportEvent: Codable {
    let version: String
    let system: SystemInfo?  // Contains its own ts
    let music: MusicInfo?    // Contains its own ts
    let activity: ActivityInfo?  // Contains its own ts
    let idempotencyKey: String?
}
```

**Reason**: Matches backend IDL where each info struct has its own timestamp.

### Music Info

**Before**:
```swift
struct MusicInfo: Codable {
    let title: String
    let artist: String
    let album: String
    let coverHash: String?
}
```

**After**:
```swift
struct MusicInfo: Codable {
    let title: String
    let artist: String
    let album: String
    let coverHash: String?  // Now properly handled via CoverService
}
```

### System Info

**Before**:
```swift
struct SystemInfo: Codable {
    let batteryPct: Double?
    let charging: Bool?
    let cpuPct: Double?
    let memoryPct: Double?
}
```

**After**: Same structure, but properly typed to match IDL (Double instead of Float)

## Service Migration

### MediaRemote Service

**Before**:
```swift
class MusicExtractor: ObservableObject {
    @Published var currentMusic: MusicSnapshot?
    
    func startExtraction() { }
    func stopExtraction() { }
}
```

**After**:
```swift
actor MediaRemoteService {
    func getMusicInfo() async throws -> MusicSnapshot?
    func startStreaming(onUpdate: (MusicSnapshot?) -> Void) async throws
    func stopStreaming()
}
```

**Migration**:
- Use async/await instead of @Published
- Call from @MainActor context
- Update UI via closures

### System Monitor

**Before**:
```swift
class SystemMonitor: ObservableObject {
    @Published var currentSystem: SystemSnapshot?
}
```

**After**:
```swift
actor SystemMonitorService {
    func getCurrentSnapshot() -> SystemSnapshot?
    func startMonitoring(interval: TimeInterval) async
}
```

### Activity Detector

**Before**:
```swift
class ActivityDetector: ObservableObject {
    @Published var currentActivity: ActivitySnapshot?
}
```

**After**:
```swift
actor ActivityDetectorService {
    func getCurrentActivity() -> ActivitySnapshot?
    func startDetection(interval: TimeInterval) async
}
```

## Breaking Changes

### 1. No More Direct Service Access

You cannot directly access services from UI anymore. Use StatusReporter as the interface.

**Before**:
```swift
let music = statusReporter.musicExtractor.currentMusic
```

**After**:
```swift
let music = reporter.currentMusic
```

### 2. Async Service Calls

Services now require async context:

**Before**:
```swift
musicExtractor.extractOnce() // Returns via callback
```

**After**:
```swift
Task {
    let music = try await mediaService.getMusicInfo()
}
```

### 3. Configuration Updates

Configuration changes now propagate automatically:

**Before**:
```swift
.onChange(of: settings.endpointURL) { _, _ in
    statusReporter.updateSettings(settings)
}
```

**After**:
```swift
// Automatic via AppCoordinator observation
// No manual onChange needed
```

## Testing Migration

### Before

```swift
let reporter = StatusReporter()
let settings = AppSettings()
reporter.updateSettings(settings)
```

### After

```swift
let coordinator = AppCoordinator.shared
let reporter = coordinator.reporter
let config = coordinator.configuration
```

## Compatibility Notes

### macOS 13.5 Support

- All async/await features work on 13.5+
- Actor isolation fully supported
- MenuBarExtra requires 13.0+ (already met)
- SwiftUI features limited to 13.5 APIs

### Removed macOS 14+ Features

- Removed usage of `onChange(of:initial:)` (14.0+)
- Simplified to use basic `onChange(of:)` (13.0+)

## Troubleshooting

### Compilation Errors

**Error**: `Cannot find type 'AppSettings' in scope`
**Fix**: Replace with `AppConfiguration`

**Error**: `Value of type 'StatusReporter' has no member 'musicExtractor'`
**Fix**: Use `reporter.currentMusic` instead

**Error**: `Cannot assign value of type 'SystemSnapshot?' to published property`
**Fix**: Access via `reporter.currentSystem`, don't try to set it directly

### Runtime Issues

**Issue**: No music detected
**Solution**: 
1. Verify MediaRemote adapter files are in bundle
2. Check whitelist configuration
3. Grant Accessibility permissions

**Issue**: Services not starting
**Solution**:
1. Check `isReportingEnabled` is true
2. Verify valid configuration (URL + key)
3. Review logs in Console.app

## Rollback Plan

If you need to rollback to old code:

1. `git checkout <previous-commit>`
2. Remove new directories: `Models/`, `Services/`, `Core/`, `Views/`, `Utilities/`
3. Restore old files from git history
4. Update Xcode project references

However, the new architecture is superior and should be preferred.

