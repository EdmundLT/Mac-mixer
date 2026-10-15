#!/bin/zsh
set -eu
cd "${0:A:h:h}"
./scripts/fetch-sparkle.sh
Vendor/Sparkle/bin/sign_update --account AppMixer --verify updates/appcast.xml
mkdir -p build/update-tests
cp updates/appcast.xml build/update-tests/tampered.xml
python3 - <<'PY'
from pathlib import Path
p=Path('build/update-tests/tampered.xml')
p.write_text(p.read_text().replace('AppMixer Updates', 'Tampered Updates'))
PY
if Vendor/Sparkle/bin/sign_update --account AppMixer --verify build/update-tests/tampered.xml > build/update-tests/tamper.log 2>&1; then
 print 'FAIL: tampered feed accepted'; exit 1
fi
print 'PASS signed feed accepted and tampered feed rejected'
build/AppMixer.app/Contents/MacOS/AppMixer --updater-smoke
