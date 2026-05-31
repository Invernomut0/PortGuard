#!/bin/bash
# Usage: ./scripts/notarize.sh <apple-id> <team-id>
# Requires: Xcode command line tools, AC_PASSWORD in keychain
# Example: xcrun notarytool store-credentials "AC_PASSWORD" --apple-id you@example.com --team-id XXXXXXXXXX
set -euo pipefail

APPLE_ID="${1:?Usage: $0 <apple-id> <team-id>}"
TEAM_ID="${2:?Usage: $0 <apple-id> <team-id>}"
SCHEME="PortGuard"
ARCHIVE="PortGuard.xcarchive"
EXPORT_DIR="export"
DMG="PortGuard.dmg"
EXPORT_PLIST="scripts/ExportOptions.plist"

echo "==> Archiving..."
xcodebuild archive \
  -project PortGuard/PortGuard.xcodeproj \
  -scheme "$SCHEME" \
  -configuration Release \
  -archivePath "$ARCHIVE" \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY="Developer ID Application" \
  DEVELOPMENT_TEAM="$TEAM_ID"

echo "==> Exporting..."
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE" \
  -exportPath "$EXPORT_DIR" \
  -exportOptionsPlist "$EXPORT_PLIST"

echo "==> Creating DMG..."
hdiutil create \
  -volname "PortGuard" \
  -srcfolder "$EXPORT_DIR/$SCHEME.app" \
  -ov -format UDZO \
  "$DMG"

echo "==> Notarizing..."
xcrun notarytool submit "$DMG" \
  --apple-id "$APPLE_ID" \
  --team-id "$TEAM_ID" \
  --password "@keychain:AC_PASSWORD" \
  --wait

echo "==> Stapling..."
xcrun stapler staple "$DMG"

echo "==> Done: $DMG"
