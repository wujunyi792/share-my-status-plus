# Share My Status - macOS Client

Modern macOS client for sharing your status (music, system metrics, and activity) with the Share My Status backend.

## Features

- 🎵 **Music Detection** - Real-time music tracking using MediaRemote Adapter
- 💻 **System Monitoring** - CPU, memory, and battery metrics
- 👤 **Activity Detection** - Track what you're working on
- 📤 **Automatic Reporting** - Configurable intervals with intelligent deduplication
- 🖼️ **Album Art Upload** - Automatic cover artwork detection and upload

## Architecture

### Modern Swift Concurrency

The app is built using Swift's modern concurrency features:

- **Actor-based Services** - All background services use actors for thread safety
- **Async/Await** - Clean asynchronous code without callbacks
- **MainActor UI** - All UI code properly isolated on main thread

### Project Structure

```
Models/
├── API/                    # API request/response models (from IDL)
├── Domain/                 # Domain models (Music, System, Activity)
└── Settings/               # App configuration

Services/                   # Actor-based services
├── Media/                  # MediaRemote music detection
├── SystemMonitorService    # System metrics collection
├── ActivityDetectorService # Activity detection
├── CoverService           # Album art management
└── NetworkService         # API communication

Core/
├── StatusReporter         # Main coordinator (@MainActor)
└── AppCoordinator         # App lifecycle management

Views/
├── MainWindow/            # Main app window tabs
├── Components/            # Reusable UI components
└── MenuBarView            # Menu bar interface

Utilities/
├── Extensions/            # Useful extensions
└── Logger                 # Structured logging
```

## Requirements

- macOS 13.5 or later
- Xcode 15.0 or later
- Swift 5.9 or later

## Setup

### 1. Install MediaRemote Adapter

Download the latest release from [mediaremote-adapter](https://github.com/ungive/mediaremote-adapter/releases):

1. Download `mediaremote-adapter.pl`
2. Download `MediaRemoteAdapter.framework`
3. Add them to your Xcode project
4. Configure build phases to copy them:
   - Script → `Contents/Resources/`
   - Framework → `Contents/Frameworks/`

See `Services/Media/README.md` for detailed instructions.

### 2. Configure Backend URL

1. Launch the app
2. Open Settings tab
3. Enter your backend URL and API key
4. Enable desired features

### 3. Grant Permissions

The app requires:
- **Accessibility** - For activity detection (window titles)
- **Network** - For reporting to backend

## Configuration

### Network Settings

- **Server URL**: Backend API endpoint (e.g., `https://api.example.com/v1/state/report`)
- **API Key**: Your authentication token
- **Report Interval**: How often to send updates (10-300 seconds)

### Feature Toggles

- **Music Reporting**: Enable/disable music detection
- **System Reporting**: Enable/disable system metrics
- **Activity Reporting**: Enable/disable activity tracking

### Advanced Settings

- **Music Whitelist**: Only report music from specific apps
- **Activity Blacklist**: Ignore specific apps from activity detection
- **Activity Rules**: Custom pattern matching for activity labels

## Development

### Building

```bash
# Open in Xcode
open share-my-status-client.xcodeproj

# Or build from command line
xcodebuild -project share-my-status-client.xcodeproj \
           -scheme share-my-status-client \
           -configuration Release
```

### Key Technologies

- **SwiftUI** - Modern declarative UI
- **Swift Concurrency** - Actors and async/await
- **Combine** - Reactive configuration updates
- **MediaRemote** - Now playing info (via adapter)
- **IOKit** - System metrics
- **ApplicationServices** - Activity detection

## API Integration

The client follows the backend IDL definitions strictly:

- `common.thrift` - Base models (Music, System, Activity)
- `state_service.thrift` - Report endpoints
- `cover_service.thrift` - Album art endpoints

All network models use proper encoding (snake_case for API, camelCase for Swift).

## License

See main project LICENSE file.

