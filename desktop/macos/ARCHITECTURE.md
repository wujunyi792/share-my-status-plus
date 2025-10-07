# macOS Client Architecture

## Overview

The macOS client is built with modern Swift concurrency patterns, using actors for thread-safe service management and SwiftUI for the user interface.

## Design Principles

1. **Actor Isolation** - All background services are actors, eliminating race conditions
2. **Async/Await** - Clean asynchronous code without callback hell
3. **Unidirectional Data Flow** - Configuration flows down, events flow up
4. **Separation of Concerns** - Clear boundaries between layers
5. **Type Safety** - Strictly typed models matching backend IDL

## Layer Architecture

```
┌─────────────────────────────────────┐
│           UI Layer                   │
│  (SwiftUI Views - @MainActor)       │
│  - ContentView                       │
│  - MenuBarView                       │
│  - StatusTabView                     │
│  - SettingsTabView                   │
└──────────────┬──────────────────────┘
               │ ObservableObject
┌──────────────▼──────────────────────┐
│      Coordination Layer              │
│  (@MainActor ObservableObject)      │
│  - AppCoordinator (singleton)        │
│  - StatusReporter                    │
└──────────────┬──────────────────────┘
               │ async/await
┌──────────────▼──────────────────────┐
│       Service Layer                  │
│  (Actors - Thread Safe)              │
│  - MediaRemoteService                │
│  - SystemMonitorService              │
│  - ActivityDetectorService           │
│  - NetworkService                    │
│  - CoverService                      │
└──────────────┬──────────────────────┘
               │
┌──────────────▼──────────────────────┐
│      System/External                 │
│  - MediaRemote (via perl adapter)    │
│  - IOKit (system metrics)            │
│  - ApplicationServices (activity)    │
│  - URLSession (network)              │
└─────────────────────────────────────┘
```

## Data Flow

### Configuration Flow (Top-Down)

```
User Input (UI)
  → AppConfiguration (@Published)
  → AppCoordinator (observes changes)
  → StatusReporter.updateConfiguration()
  → Individual Services (via async calls)
```

### Status Flow (Bottom-Up)

```
System APIs
  → Service Actors (collect data)
  → StatusReporter (coordinates)
  → Published Properties (@MainActor)
  → UI Updates (SwiftUI)
```

### Reporting Flow

```
Timer Trigger
  → StatusReporter.performReport()
  → Collect from all services (parallel)
  → CoverService.checkAndUploadCover() [if needed]
  → Build ReportEvent
  → NetworkService.reportStatus()
  → Update UI state
```

## Actor Services

### MediaRemoteService

**Responsibility**: Extract music information from MediaRemote framework

**Key Methods**:
- `getMusicInfo()` - One-time fetch
- `startStreaming(onUpdate:)` - Real-time updates
- `stopStreaming()` - Stop updates
- `testAdapter()` - Verify functionality

**Implementation**:
- Uses `/usr/bin/perl` to invoke MediaRemote adapter
- Parses JSON output from adapter
- Filters by whitelist
- Provides async streaming interface

### SystemMonitorService

**Responsibility**: Collect system metrics (CPU, memory, battery)

**Key Methods**:
- `startMonitoring(interval:)` - Start periodic collection
- `stopMonitoring()` - Stop collection
- `getCurrentSnapshot()` - Get latest metrics
- `collectMetrics()` - Manual collection

**Implementation**:
- Uses IOKit for battery info
- Uses Mach APIs for CPU/memory
- Collects every 10 seconds by default
- Thread-safe via actor isolation

### ActivityDetectorService

**Responsibility**: Detect user activity and frontmost application

**Key Methods**:
- `startDetection(interval:)` - Start periodic detection
- `stopDetection()` - Stop detection
- `getCurrentActivity()` - Get latest activity
- `updateRules()` - Update pattern matching rules

**Implementation**:
- Uses ApplicationServices for window info
- Checks Accessibility permissions
- Pattern matching for activity labels
- Blacklist filtering

### NetworkService

**Responsibility**: Handle all HTTP communication with backend

**Key Methods**:
- `reportStatus()` - Send batch report
- `updateConfiguration()` - Update endpoint/auth
- `getStatistics()` - Get report stats

**Implementation**:
- URLSession with proper timeouts
- Network path monitoring
- Automatic retry logic
- Proper error handling

### CoverService

**Responsibility**: Manage album artwork upload and caching

**Key Methods**:
- `checkAndUploadCover()` - Smart upload with caching
- `clearCache()` - Clear upload cache

**Implementation**:
- MD5-based deduplication
- Checks server before upload
- Local cache for uploaded covers
- Base64 encoding for transport

## Coordination Layer

### AppCoordinator

**Responsibility**: Manage app lifecycle and global state

**Pattern**: Singleton (@MainActor)

**Key Features**:
- Single source of truth for configuration and reporter
- Observes configuration changes
- Coordinates app startup/shutdown
- Accessible via `AppCoordinator.shared`

### StatusReporter

**Responsibility**: Coordinate all services and perform reporting

**Pattern**: ObservableObject (@MainActor)

**Key Features**:
- Manages all service actors
- Collects data from all sources
- Orchestrates cover upload before reporting
- Handles timer-based reporting
- Updates UI via @Published properties

## Thread Safety

### Actor Isolation

All services are actors, which means:
- No data races
- Automatic synchronization
- Safe concurrent access
- Methods are `async` by default

### Main Actor

UI code is marked `@MainActor`:
- Configuration
- StatusReporter
- All Views

This ensures UI updates happen on the main thread.

### Communication

```swift
// From MainActor to Actor (async call)
let music = await mediaService.getCurrentMusic()

// From Actor to MainActor (via closure)
try await mediaService.startStreaming { music in
    Task { @MainActor in
        self.currentMusic = music
    }
}
```

## Error Handling

### Service-Level Errors

Each service defines its own error types:
- `MediaRemoteError`
- `NetworkError`
- `CoverError`
- `ProcessError`

### Error Propagation

```
Service Error
  → throws to StatusReporter
  → Caught and stored in lastError
  → Displayed in UI
```

### Non-Fatal Errors

Services log warnings but continue operation:
- MediaRemote stream interruption
- Network temporary failures
- Cover upload failures (report continues)

## Performance Considerations

### Intervals

- Music: Real-time streaming (event-driven)
- System: 10 seconds (low overhead)
- Activity: 5 seconds (balance accuracy/performance)
- Reporting: Configurable (default 5 seconds)

### Resource Usage

- Actors run on background threads
- UI updates batched on main thread
- Network requests pooled via URLSession
- Cover uploads cached to avoid duplicates

## Compatibility

### macOS Version Support

- **Minimum**: macOS 13.5
- **Recommended**: macOS 14.0+
- **Tested**: macOS 13.5 - 15.4+

### Feature Availability

- MenuBarExtra: macOS 13.0+ (gracefully degrades)
- SF Symbols: Uses fallbacks for older versions
- Concurrency: Full support on 13.5+

### MediaRemote

Works on all macOS versions via adapter:
- macOS 13.x: ✓
- macOS 14.x: ✓
- macOS 15.4+: ✓ (main benefit of adapter)

## Testing

### Unit Testing

Test individual actors:
```swift
let service = MediaRemoteService()
let music = try await service.getMusicInfo()
XCTAssertNotNil(music)
```

### Integration Testing

Test full flow:
```swift
let coordinator = AppCoordinator.shared
coordinator.reporter.startReporting()
// Wait and verify reports sent
```

### Manual Testing

1. Check music detection with various players
2. Verify system metrics accuracy
3. Test activity detection with different apps
4. Confirm reporting to backend

## Debugging

### Enable Logging

Check Console.app and filter by:
- Subsystem: `com.wujunyi792.share-my-status-client`
- Categories: Media, System, Activity, Network, Cover, Reporter

### Common Issues

**No music detected**:
- Check MediaRemote adapter files exist
- Verify whitelist configuration
- Test adapter manually (see Services/Media/README.md)

**High CPU usage**:
- Check polling intervals
- Verify services stop when disabled
- Monitor for runaway tasks

**Network failures**:
- Check endpoint URL format
- Verify API key
- Test network connectivity
- Review Console logs

## Future Enhancements

Potential improvements:
- [ ] Local SQLite cache for offline queueing
- [ ] More sophisticated retry logic
- [ ] Custom activity rules UI editor
- [ ] Statistics dashboard
- [ ] Export/import configuration

