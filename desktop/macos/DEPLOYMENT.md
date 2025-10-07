# macOS Client Deployment Guide

## Prerequisites

1. **Xcode 15+** installed
2. **Apple Developer Account** (for code signing)
3. **MediaRemote Adapter files** downloaded

## Step 1: Download MediaRemote Adapter

Visit https://github.com/ungive/mediaremote-adapter/releases and download:

1. `mediaremote-adapter.pl` (latest version)
2. `MediaRemoteAdapter.framework` (latest version)

## Step 2: Add Files to Xcode Project

1. Open `share-my-status-client.xcodeproj`
2. Drag and drop files into the project:
   - `mediaremote-adapter.pl` → Add to project, but **don't** add to target
   - `MediaRemoteAdapter.framework` → Add to project and target

## Step 3: Configure Build Phases

1. Select the target in Xcode
2. Go to "Build Phases"
3. Add "Copy Files" phase (if not exists):

**Phase 1: Copy Script**
- Destination: Resources
- Files: `mediaremote-adapter.pl`
- Code Sign On Copy: ✓

**Phase 2: Copy Framework**
- Destination: Frameworks  
- Files: `MediaRemoteAdapter.framework`
- Code Sign On Copy: ✓

## Step 4: Configure Deployment Target

1. Select target
2. Go to "Build Settings"
3. Set `MACOSX_DEPLOYMENT_TARGET` = `13.5`

## Step 5: Configure Code Signing

1. Select target → "Signing & Capabilities"
2. Choose your development team
3. Ensure these capabilities are enabled:
   - App Sandbox
   - Hardened Runtime
   - Network (Outgoing Connections)

## Step 6: Build

### Debug Build
```bash
xcodebuild -project share-my-status-client.xcodeproj \
           -scheme share-my-status-client \
           -configuration Debug \
           build
```

### Release Build
```bash
xcodebuild -project share-my-status-client.xcodeproj \
           -scheme share-my-status-client \
           -configuration Release \
           build
```

The app will be in:
`build/Release/share-my-status-client.app`

## Step 7: Distribution

### Option 1: Direct Distribution (Development)
- Share the `.app` bundle directly
- Users must grant Accessibility permissions manually

### Option 2: App Store
- Requires full app review process
- Need to explain MediaRemote usage in review notes

### Option 3: Notarization
```bash
# Archive
xcodebuild archive -project share-my-status-client.xcodeproj \
                   -scheme share-my-status-client \
                   -archivePath build/ShareMyStatus.xcarchive

# Export for notarization
xcodebuild -exportArchive \
           -archivePath build/ShareMyStatus.xcarchive \
           -exportPath build/ \
           -exportOptionsPlist ExportOptions.plist

# Notarize
xcrun notarytool submit build/ShareMyStatus.app.zip \
     --apple-id YOUR_EMAIL \
     --team-id YOUR_TEAM_ID \
     --password YOUR_APP_SPECIFIC_PASSWORD

# Staple
xcrun stapler staple build/ShareMyStatus.app
```

## Troubleshooting

### MediaRemote Not Working

1. Verify files are in the correct locations:
   ```bash
   ls -la ShareMyStatus.app/Contents/Resources/mediaremote-adapter.pl
   ls -la ShareMyStatus.app/Contents/Frameworks/MediaRemoteAdapter.framework
   ```

2. Check permissions:
   ```bash
   chmod +x ShareMyStatus.app/Contents/Resources/mediaremote-adapter.pl
   ```

3. Test manually:
   ```bash
   /usr/bin/perl \
     ShareMyStatus.app/Contents/Resources/mediaremote-adapter.pl \
     ShareMyStatus.app/Contents/Frameworks/MediaRemoteAdapter.framework \
     get
   ```

### Accessibility Permissions

If activity detection doesn't work:
1. System Settings → Privacy & Security → Accessibility
2. Add Share My Status
3. Enable the toggle

### Code Signing Issues

If the app crashes on launch:
1. Check code signing: `codesign -dvvv ShareMyStatus.app`
2. Verify entitlements: `codesign -d --entitlements - ShareMyStatus.app`
3. Re-sign if necessary: `codesign -f -s "Developer ID" ShareMyStatus.app`

## Updating

When updating the MediaRemote Adapter:
1. Download new version
2. Replace files in project
3. Clean build folder (Cmd+Shift+K)
4. Rebuild

## Support

For issues related to:
- **MediaRemote**: https://github.com/ungive/mediaremote-adapter/issues
- **App functionality**: File issue in main project repo

