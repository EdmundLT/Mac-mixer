#!/bin/zsh
set -eu
cd "${0:A:h:h}"
mkdir -p build/AppMixer.app/Contents/MacOS
clang -c Sources/AudioDSP/AudioDSP.c -I Sources/AudioDSP/include -o build/AudioDSP.o -mmacosx-version-min=14.2
swiftc -module-cache-path build/ModuleCache -parse-as-library -target arm64-apple-macosx14.2 -I Sources/AudioDSP/include Sources/AppMixer/*.swift build/AudioDSP.o -o build/AppMixer.app/Contents/MacOS/AppMixer -framework CoreAudio -framework AppKit -framework SwiftUI
cp Info.plist build/AppMixer.app/Contents/Info.plist
codesign --force --sign - build/AppMixer.app
