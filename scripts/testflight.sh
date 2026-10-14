#!/bin/bash
# Archives the iOS app and uploads it to App Store Connect for TestFlight,
# using the Apple ID signed into Xcode (Settings → Accounts).
#
# Every upload needs a new build number; this uses the UTC date and time
# (e.g. 20261012.1830), so it always increases without editing anything.
set -euo pipefail
cd "$(dirname "$0")/.."

BUILD_NUMBER="$(date -u +%Y%m%d).$(date -u +%H%M)"
ARCHIVE=.build/Pace.xcarchive

xcodegen generate --quiet
rm -rf "$ARCHIVE" .build/export

xcodebuild archive \
    -project PaceCalculator.xcodeproj \
    -scheme PaceCalculator \
    -destination 'generic/platform=iOS' \
    -archivePath "$ARCHIVE" \
    -allowProvisioningUpdates \
    CURRENT_PROJECT_VERSION="$BUILD_NUMBER"

xcodebuild -exportArchive \
    -archivePath "$ARCHIVE" \
    -exportOptionsPlist scripts/ExportOptions.plist \
    -exportPath .build/export \
    -allowProvisioningUpdates

echo "Uploaded build $BUILD_NUMBER. It appears in App Store Connect → TestFlight after processing (usually 5–30 minutes)."
