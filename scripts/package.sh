#!/bin/zsh
set -eu
cd "${0:A:h:h}"
./scripts/build.sh
./scripts/test.sh
mkdir -p dist build/dmg-stage
version=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' Info.plist)
name="AppMixer-${version}-macOS-arm64"
/usr/bin/ditto -c -k --sequesterRsrc --keepParent build/AppMixer.app "dist/${name}.zip"
/usr/bin/ditto build/AppMixer.app build/dmg-stage/AppMixer.app
ln -sfn /Applications build/dmg-stage/Applications
cp INSTALL.txt build/dmg-stage/READ-ME.txt
hdiutil create -volname AppMixer -srcfolder build/dmg-stage -ov -format UDZO "dist/${name}.dmg"
(cd dist && shasum -a 256 "${name}.zip" "${name}.dmg" > SHA256SUMS.txt)
codesign --verify --strict build/AppMixer.app
hdiutil verify "dist/${name}.dmg"
