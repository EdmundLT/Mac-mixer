#!/bin/zsh
set -eu
cd "${0:A:h:h}"
version=2.10.0
checksum=c2bf58aa8387266ac179357b1415d6f2635f044da8be41042af32425dae6da0c
archive="Vendor/Sparkle-${version}.tar.xz"
mkdir -p Vendor
if [[ ! -f "$archive" ]]; then
 curl --fail --location --proto '=https' --tlsv1.2 "https://github.com/sparkle-project/Sparkle/releases/download/${version}/Sparkle-${version}.tar.xz" -o "$archive"
fi
print "$checksum  $archive" | shasum -a 256 -c -
if [[ ! -f Vendor/Sparkle/.verified-2.10.0 ]]; then
 mkdir -p Vendor/Sparkle
 tar -xf "$archive" -C Vendor/Sparkle
 touch Vendor/Sparkle/.verified-2.10.0
fi
