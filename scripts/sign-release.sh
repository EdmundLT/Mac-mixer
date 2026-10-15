#!/bin/zsh
# Sign a built bundle from the inside out. No upload or notarization is performed.
set -eu
cd "${0:A:h:h}"
: "${SIGNING_IDENTITY:?Set SIGNING_IDENTITY to your Developer ID Application identity}"
app="${1:-build/AppMixer.app}"
framework="$app/Contents/Frameworks/Sparkle.framework"
for component in "$framework/Versions/B/Autoupdate" "$framework/Versions/B/Updater.app" "$framework/Versions/B/XPCServices/Downloader.xpc" "$framework/Versions/B/XPCServices/Installer.xpc" "$framework" "$app"; do
 codesign --force --options runtime --timestamp --sign "$SIGNING_IDENTITY" "$component"
done
codesign --verify --deep --strict --verbose=2 "$app"
