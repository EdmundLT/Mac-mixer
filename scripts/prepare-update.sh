#!/bin/zsh
# Produces a candidate feed only. Upload the exact archive first; publish feed last.
set -eu
cd "${0:A:h:h}"
archive="${1:?Usage: prepare-update.sh /absolute/path/to/notarized.zip version}"
version="${2:?Specify release version, e.g. 0.2.0}"
[[ "$version" == [0-9]* && "$version" != *[^0-9.]* ]] || { print 'Invalid release version'; exit 1; }
[[ "$archive" == /* && -f "$archive" && "$archive" == *.zip ]] || { print 'Provide an absolute path to a ZIP'; exit 1; }
./scripts/fetch-sparkle.sh
stage=$(mktemp -d "$PWD/build/update-feed.XXXXXX")
ditto -x -k "$archive" "$stage"
app="$stage/AppMixer.app"
xcrun stapler validate "$app"
codesign --verify --deep --strict "$app"
spctl --assess --type execute "$app"
[[ "$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$app/Contents/Info.plist")" == "$version" ]] || { print 'Version mismatch'; exit 1; }
mkdir -p "$stage/archives"
cp "$archive" "$stage/archives/"
cp updates/appcast.xml "$stage/archives/appcast.xml"
Vendor/Sparkle/bin/generate_appcast --account AppMixer --maximum-deltas 0 --download-url-prefix "https://github.com/EdmundLT/Mac-mixer/releases/download/v${version}/" "$stage/archives"
Vendor/Sparkle/bin/sign_update --account AppMixer --verify "$stage/archives/appcast.xml"
print "Candidate feed: $stage/archives/appcast.xml"
print 'Upload the exact ZIP, verify its remote SHA-256, then publish this feed. No files have been published.'
