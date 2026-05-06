#!/bin/bash
# Quick TestFlight Build Script for FitDays iOS App

set -e

PROJECT_DIR="/Users/vanampranav/StudioProjects/app"
IOS_DIR="$PROJECT_DIR/ios"
TEAM_ID="UJMW9NXB22"
ARCHIVE_PATH="$IOS_DIR/build/Runner.xcarchive"
EXPORT_PATH="$PROJECT_DIR/build/testflight"

echo "🚀 Starting iOS TestFlight Build..."
echo "================================================"

# Step 1: Clean previous builds
echo "📦 Cleaning previous builds..."
rm -rf "$ARCHIVE_PATH"  
rm -rf "$EXPORT_PATH"
rm -rf "$PROJECT_DIR/build/ipa"

# Step 2: Install dependencies
echo "📚 Installing CocoaPods..."
cd "$IOS_DIR"
pod install --repo-update > /dev/null 2>&1 || pod install > /dev/null 2>&1

# Step 3: Build archive
echo "🔨 Building archive for Release..."
xcodebuild archive \
  -workspace Runner.xcworkspace \
  -scheme Runner \
  -configuration Release \
  -archivePath "$ARCHIVE_PATH" \
  -allowProvisioningUpdates \
  -verbose 2>&1 | grep -E "SUCCEEDED|FAILED|error:" || true

# Check if archive was created
if [ -d "$ARCHIVE_PATH" ]; then
  echo "✅ Archive created successfully!"
  echo "   Location: $ARCHIVE_PATH"
else
  echo "❌ Archive creation failed!"
  exit 1
fi

# Step 4: Create export options plist
echo "⚙️  Creating export configuration..."
mkdir -p "$EXPORT_PATH"

cat > "$EXPORT_PATH/ExportOptions.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/ DTDs/PropertyList-1.0.dtd">
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

# Step 5: Export IPA
echo "📤 Exporting IPA for TestFlight..."
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportOptionsPlist "$EXPORT_PATH/ExportOptions.plist" \
  -exportPath "$EXPORT_PATH/ipa" \
  -allowProvisioningUpdates

# Verify IPA
if [ -f "$EXPORT_PATH/ipa/Runner.ipa" ]; then
  IPA_SIZE=$(ls -lh "$EXPORT_PATH/ipa/Runner.ipa" | awk '{print $5}')
  echo "✅ IPA exported successfully!"
  echo "   Size: $IPA_SIZE"
  echo "   Path: $EXPORT_PATH/ipa/Runner.ipa"
  echo ""
  echo "================================================"
  echo "🎉 Ready for TestFlight!"
  echo "================================================"
  echo ""
  echo "Next steps:"
  echo "1. Open Xcode organizer: open ios/Runner.xcworkspace"
  echo "2. Window → Organizer → Archives"
  echo "3. Select 'Runner' archive → Distribute App"
  echo "4. Choose TestFlight → Automatic signing → Upload"
  echo ""
  echo "Or use Transporter app to upload the IPA"
  echo "Drag & drop: $EXPORT_PATH/ipa/Runner.ipa"
else
  echo "❌ IPA export failed!"
  exit 1
fi

echo ""
echo "All done! ✨"
