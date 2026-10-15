# AppMixer — macOS per-application volume prototype

Independent macOS menu-bar application.
App: `build/AppMixer.app`. No files from the screenshot-tool project are used.

## Build and run

Requires Apple Silicon, macOS 14.2+, Swift compiler and SDK with Core Audio taps. This machine: macOS 26.6.2 (25G83), Swift 6.3.3, Command Line Tools; no full Xcode required.

```sh
./scripts/build.sh
./scripts/test.sh
open build/AppMixer.app
```

The app automatically attempts activation once per launch. It first creates and immediately destroys a private, unmuted, empty-inclusion tap so macOS can request system audio recording consent even with no active playback. That temporary tap is never attached to a device or read. macOS decides whether to show a prompt based on its existing permission state; only the user approves it. After successful setup, new playback is detected automatically. If activation fails, the app stops and shows an error; use **Enable Volume Control** to retry. It never retries activation in the polling loop. This is app-launch activation, not login-item registration.

Preview without audio: `build/AppMixer.app/Contents/MacOS/AppMixer --demo --render-preview`. Produces `build/preview.png`, runs UI model checks, and exits. Run from the project directory.

Swift Package Manager is currently broken on this Mac: `swift-package` fails at dynamic loading with a missing BuildServerProtocol symbol. The supported local build/test scripts use clang and swiftc directly with a workspace-local module cache. Package.swift and XCTest sources are also included for a repaired toolchain. No SDK install, developer login, certificates, or license agreement was performed. The bundle is locally ad-hoc signed, not notarized.

## Audio design

Official reference: https://developer.apple.com/documentation/coreaudio/capturing-system-audio-with-core-audio-taps

The installed Apple CoreAudio SDK headers (`CATapDescription.h`, `AudioHardware.h`, `AudioHardwareTapping.h`) were also inspected. In particular, Apple's `mutedWhenTapped` contract mutes the original route only while an audio client reads the tap.

- Enumerate HAL audio process objects, read their bundle IDs/PIDs/output-active state, and group Chrome helper bundle IDs under `com.google.Chrome`; Spotify helpers under `com.spotify.client`. Chrome Canary remains separate. This is app-level, not tab-level control. Active IO does not necessarily mean audible sound.
- Each active group gets its own private, device-specific tap and private aggregate device using the current default output as its only subdevice. The tool never sets the system default output or installs a driver.
- Each group's callback copies only that group's tapped Float32 samples to that group's output, applying independent 0–1 gain. Short per-buffer gain ramps reduce slider clicks. No file recording, network, buffer queue, or growing recording storage exists. The C real-time callback does not allocate, lock, log, or call Swift.
- The aggregate uses the physical output clock and tap drift compensation. The original app output is muted via `mutedWhenTapped` while reading; AppMixer's own PID is excluded from discovery to avoid recapturing its playback.
- Failure during setup unwinds IOProc, aggregate device, and tap. Stop/normal quit does the same. Sleep stops sessions. A one-second health poll stops all sessions on output-device changes, callback-format failure, or three missed heartbeat polls. Process object changes rebuild the affected session, preserving the app's chosen level.
- Topologies are intentionally restricted: one Float32 stereo output stream, no hardware input streams, matching tap/output sample rates and formats, and matching callback buffer layouts. Built-in speakers are the first acceptance target. Bluetooth headsets, multichannel devices, and devices with input streams may be rejected. No conversion/resampling fallback is implemented.

## Verified here

- Direct clang/swiftc build succeeded; bundle metadata and ad-hoc signature verified.
- `build/test.log`: 13 deterministic tests passed (helper grouping boundaries, independent levels/mute, clamps, stereo gain ramp, silence, unity restoration, callback heartbeat, topology mismatch fail-safe).
- `build/test-host.log`: same 13 tests passed outside the execution sandbox; read-only HAL discovery returned 31 app groups. Sandbox-only discovery returned zero, so its empty list was not treated as a host result.
- `build/preview.png`: real native SwiftUI rendering, visually inspected for readable text, distinct sliders/mute buttons, and spacing. The preview path additionally exercises four independent UI model assertions. This does not certify mouse/keyboard interaction or menu-bar placement.
- Validation used the no-audio demo and synthetic tests only: no process tap was created by those tests, no capture permission accepted, and no private playback started. The new automatic consent/activation path still needs user-assisted verification. **Compilation, synthetic tests and preview do not establish that live audio routing works.**

## User-assisted acceptance still required

Start with built-in speakers, choose comfortable source/system levels, and use public test music you select in Chrome and Spotify:

1. At 100% each, launch the app (automatic activation) and explicitly respond to macOS audio permission. Confirm no doubling, echo, or dropout compared with standby.
2. Lower Chrome to 25%, keeping Spotify at 100%; confirm only Chrome changes. Reverse the experiment. Compare 0%, 50%, and 100%.
3. Mute each app independently; unmute must restore its previous slider value. Verify both muted simultaneously.
4. Stop control and quit normally; confirm both return to their own original volume. Separately verify force-quit/crash recovery: `mutedWhenTapped` is a safety mechanism, not proof that crash recovery has been tested.
5. Restart Chrome/its audio helper and Spotify while controlling. Check grouping, restored level, and absence of duplicate playback. Polling/recreation can briefly restore full original volume; seamless restart is not promised.
6. Deny/revoke permission and check safe recovery. Change output, sleep/wake, and verify the tool stops and requires explicit re-enable. AirPods only after built-in speaker validation, if their topology is supported.
7. Run longer playback and listen for drift/dropouts. Actual latency, fidelity, CPU use, and independent live gain remain unmeasured.

Known limitations: cleanup calls are best-effort Core Audio teardown; a callback error may cause a brief silence until the next health poll. Other volume utilities/taps can conflict and are not detected. Controls are session-only, no saved preferences. App restart/rebuild at ad-hoc signing identity may require macOS permission to be granted again. Process grouping uses known bundle-ID prefixes; unusual Chrome builds/helpers need verification. This is an unvalidated audio prototype, not a production audio mixer.

## Distribution

Run `./scripts/package.sh` to build, test and produce Apple Silicon ZIP/DMG archives and SHA-256 checksums in `dist/`. The DMG includes an Applications shortcut and installation notes. Release downloads are preview builds, ad-hoc signed but not Apple notarized. See `INSTALL.txt` for installation and limitations.
