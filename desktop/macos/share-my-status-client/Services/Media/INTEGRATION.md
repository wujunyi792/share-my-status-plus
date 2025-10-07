# MediaRemote Adapter Integration

## Overview

This service uses the [mediaremote-adapter](https://github.com/ungive/mediaremote-adapter) to access MediaRemote framework on macOS 15.4+.

## Required Files

You need to download and add the following files to your Xcode project:

1. **mediaremote-adapter.pl** (Perl script)
   - Download from: https://github.com/ungive/mediaremote-adapter/releases
   - Target location: `Contents/Resources/mediaremote-adapter.pl`

2. **MediaRemoteAdapter.framework** (Helper framework)
   - Download from: https://github.com/ungive/mediaremote-adapter/releases
   - Target location: `Contents/Frameworks/MediaRemoteAdapter.framework`

## Xcode Configuration

### Add Build Phase

1. Open Xcode project settings
2. Select the target
3. Go to "Build Phases"
4. Add a new "Copy Files" phase (if not already exists)
5. Configure two copy operations:

**Copy Script:**
- Destination: Resources
- Subpath: (leave empty)
- Files: mediaremote-adapter.pl

**Copy Framework:**
- Destination: Frameworks
- Subpath: (leave empty)  
- Files: MediaRemoteAdapter.framework

### Add to App Sandbox Entitlements

Since the app uses `/usr/bin/perl` to invoke MediaRemote, ensure your entitlements include:

```xml
<key>com.apple.security.app-sandbox</key>
<true/>
<key>com.apple.security.files.user-selected.read-only</key>
<true/>
```

## Usage

The `MediaRemoteService` actor handles all MediaRemote operations:

```swift
let service = MediaRemoteService()

// Get current music (one-time)
let music = try await service.getMusicInfo()

// Stream real-time updates
try await service.startStreaming { music in
    print("Music updated: \(music?.title ?? "None")")
}

// Test if adapter works
let isWorking = try await service.testAdapter()
```

## Troubleshooting

If music detection doesn't work:

1. Verify both files exist in the app bundle
2. Check file permissions (must be executable)
3. Run the test command to verify functionality
4. Check Console.app for MediaRemote errors

## References

- [MediaRemote Adapter Project](https://github.com/ungive/mediaremote-adapter)
- [MediaRemote Breaking Issues](https://github.com/ungive/mediaremote-adapter#useful-links)

