#!/bin/zsh
set -eu
cd "${0:A:h:h}"
./scripts/fetch-sparkle.sh
mkdir -p build/AppMixer.app/Contents/MacOS build/AppMixer.app/Contents/Frameworks build/AppMixer.app/Contents/Resources
ditto Vendor/Sparkle/Sparkle.framework build/AppMixer.app/Contents/Frameworks/Sparkle.framework
cp Vendor/Sparkle/LICENSE build/AppMixer.app/Contents/Resources/Sparkle-LICENSE.txt
clang -c Sources/AudioDSP/AudioDSP.c -I Sources/AudioDSP/include -o build/AudioDSP.o -mmacosx-version-min=14.2
swiftc -module-cache-path build/ModuleCache -parse-as-library -target arm64-apple-macosx14.2 -I Sources/AudioDSP/include Sources/AppMixer/*.swift build/AudioDSP.o -o build/AppMixer.app/Contents/MacOS/AppMixer -framework CoreAudio -framework AppKit -framework SwiftUI -F Vendor/Sparkle -framework Sparkle -Xlinker -rpath -Xlinker @executable_path/../Frameworks
cp Info.plist build/AppMixer.app/Contents/Info.plist
codesign --force --sign - build/AppMixer.app
