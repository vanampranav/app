# iOS TestFlight Submission Guide

## Current Status
✅ **FitDays SDK Integration Complete**
✅ **Code Compilation Successful**  
✅ **IPA Package Created** at `build/Runner.ipa`

⚠️ **Action Required: Code Signing for TestFlight**

---

## Step 1: Set Up Code Signing

### Option A: Automatic Signing (Recommended)

1. Open Xcode project:
   ```bash
   open ios/Runner.xcworkspace
   ```

2. Select the **Runner** target
3. Go to **Signing & Capabilities** tab
4. Enable **Automatically manage signing**
5. Select your **Team** from the dropdown
6. Connect an Apple Developer account:
   - Xcode → Preferences → Accounts
   - Click + to add your Apple ID
   - Sign in with your Apple Developer account

### Option B: Manual Code Signing

If you have development certificates already installed:

1. Identify your Certificate and Provisioning Profile info:
   ```bash
   security find-certificate -c "Apple Development" ~/Library/Keychains/login.keychain
   ```

2. Build with signing:
   ```bash
   cd /Users/vanampranav/StudioProjects/app
   xcodebuild -workspace ios/Runner.xcworkspace \
     -scheme Runner \
     -configuration Release \
     -derivedDataPath build-signed \
     -allowProvisioningUpdates \
     -authorizationProvisioning
   ```

---

## Step 2: Create Signed Archive for TestFlight

Once signing is configured, run:

```bash
cd /Users/vanampranav/StudioProjects/app/ios

# Clean previous builds
rm -rf build/Runner.xcarchive

# Create archive
xcodebuild archive \
  -workspace Runner.xcworkspace \
  -scheme Runner \
  -archivePath ./build/Runner.xcarchive \
  -configuration Release \
  -allowProvisioningUpdates

# Verify archive was created
ls -lh build/Runner.xcarchive
```

---

## Step 3: Export to TestFlight

### Option A: Using Xcode Organizer (Easiest)

1. Open Xcode:
   ```bash
   open ios/Runner.xcworkspace
   ```

2. Go to **Window → Organizer**
3. Select **Archives** tab
4. Find and select the latest **Runner** archive
5. Click **Distribute App**
6. Choose **TestFlight**
7. Select options and sign with your team
8. Upload to TestFlight

### Option B: Using Command Line

```bash
cd /Users/vanampranav/StudioProjects/app

# Create export options plist
cat > export_options.plist << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>app-store</string>
    <key>signingStyle</key>
    <string>automatic</string>
    <key>stripSwiftSymbols</key>
    <true/>
    <key>teamID</key>
    <string>UJMW9NXB22</string>
</dict>
</plist>
EOF

# Export IPA from archive
xcodebuild -exportArchive \
  -archivePath ios/build/Runner.xcarchive \
  -exportOptionsPlist export_options.plist \
  -exportPath build/testflight_ipa

# Verify IPA
ls -lh build/testflight_ipa/*.ipa
```

---

## Step 4: Upload to App Store Connect

### Using Transporter:

```bash
# Install Transporter (if not already installed)
# Available from App Store or download from Apple

# Open Transporter and import the IPA, then upload
```

### Or Upload from Xcode Organizer:

1. Window → Organizer
2. Archives tab
3. Select archive → Distribute App
4. Choose TestFlight → Automatic signing → Upload

---

## Build Info Summary

- **App Name:** Elefit
- **Bundle ID:** com.example.elefitApp
- **Team ID:** UJMW9NXB22
- **Version:** 1.0.2
- **Build Number:** 5
- **iOS Deployment Target:** 14.0

---

## FitDays SDK Integration Summary

✅ **Completed:**
- FitDaysSDKManager.swift (416 lines) - Full SDK wrapper
- Runner-Bridging-Header.h - All framework imports
- AppDelegate.swift - Method & event channel setup
- All Swift/Objective-C interop fixes
- Enum type handling (rawValue initialization)
- Callback comparisons (state.rawValue checks)

✅ **Features Implemented:**
- User info initialization
- Device scanning & discovery
- Device connection/disconnection
- Weight data reception with body composition
- Kitchen scale unit conversion
- Bluetooth permission checks
- Tare & unit change commands for scales
- Complete event streaming to Flutter

---

## Next Steps

1. Ensure Apple Developer account is active
2. Set up code signing certificates (Xcode → Preferences → Accounts)
3. Choose Option A or B from Step 2 above
4. Complete Step 3 to upload to TestFlight
5. Monitor TestFlight in App Store Connect
6. Create test builds in TestFlight for device testing

---

## Troubleshooting

**Problem:** "No matching provisioning profile found"
- Run: `xcodebuild -allowProvisioningUpdates`
- Or manually create provisioning profile in developer.apple.com

**Problem:** "Code signing requires a development team"
- Xcode → Preferences → Accounts → Add Apple ID
- Project → Signing & Capabilities → Select Team

**Problem:** Archive creation fails
- Run: `pod install` to sync dependencies
- Clean: `flutter clean && rm -rf build ios/Pods Podfile.lock`
- Rebuild: `flutter pub get && flutter build ios --release`

---

For additional help: https://developer.apple.com/testflight/
