#!/bin/zsh
set -eu
cd "${0:A:h:h}"
mkdir -p build
clang -c Sources/AudioDSP/AudioDSP.c -I Sources/AudioDSP/include -o build/AudioDSP.o -mmacosx-version-min=14.2
swiftc -module-cache-path build/ModuleCache -target arm64-apple-macosx14.2 -I Sources/AudioDSP/include Sources/AppMixer/Audio.swift Sources/AppMixer/Level.swift Sources/AppMixer/LoginItem.swift Tests/Standalone.swift build/AudioDSP.o -o build/checks -framework CoreAudio -framework AppKit
build/checks
