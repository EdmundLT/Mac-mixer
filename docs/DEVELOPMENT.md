# Development and distribution

[Back to README](../README.md)

## Build and test

The maintained build path uses `clang` and `swiftc` from Apple's Command Line Tools. Full Xcode is not required. `Package.swift` also declares the project and its pinned Sparkle dependency, but Swift Package Manager was unavailable on the development Mac because of a BuildServerProtocol dynamic-linking error.

```sh
./scripts/build.sh
./scripts/test.sh
./scripts/test-updates.sh
```

- `build.sh` downloads Sparkle 2.10.0, verifies the pinned SHA-256, embeds its framework/helpers/license, and builds an arm64 app at `build/AppMixer.app` with an ad-hoc signature.
- `test.sh` runs 19 checks covering grouping, gain/mute, callback safeguards and login-item state handling. No tap is created.
- `test-updates.sh` requires the AppMixer Sparkle key in the local Keychain. It verifies the signed feed, rejects a modified feed and initializes Sparkle inside the app without checking or installing an update.

```sh
# Native UI screenshot; no audio or updater startup.
build/AppMixer.app/Contents/MacOS/AppMixer --demo --render-preview

# Real HTTPS feed check; information only, no audio/download/install.
build/AppMixer.app/Contents/MacOS/AppMixer --check-feed
```

The screenshot is written to `build/preview.png`. The README's image is a checked-in copy in `docs/images/`; retain its demo-mode caption when replacing it.

## Audio architecture

Based on Apple's [Core Audio process taps](https://developer.apple.com/documentation/coreaudio/capturing-system-audio-with-core-audio-taps).

1. Enumerate HAL audio process objects and group known Chrome/Spotify helper bundle IDs. Exclude AppMixer's own PID. Active IO is not proof of audible sound.
2. Create a private device-specific process tap per active group. Use `mutedWhenTapped` so original output is muted while the tap is read.
3. Attach each tap to a private aggregate using the current output device, its clock, and tap drift compensation. Never set the system default output.
4. A C real-time callback applies independent gain with a per-buffer ramp. It performs no allocation, locking, logging or Swift calls.
5. Teardown stops the IOProc, destroys the aggregate, and destroys the tap. A one-second poll checks topology, process IDs and callback health. Sleep/output changes stop control; process changes rebuild the affected session.

Supported layouts are intentionally narrow: one Float32 stereo output stream, no physical input streams, matching sample rates/formats and matching callback buffer layouts. There is no resampling fallback. Cleanup is best-effort; errors can cause brief silence until the next poll. Process rebuilding can briefly restore original full volume. Competing audio utilities are not detected.

## Login and updates

Login startup uses `SMAppService.mainApp`. Registration only occurs when the user enables the switch. The UI reads OS status and exposes pending approval; no separate preference duplicates that state.

Sparkle uses an HTTPS feed at `updates/appcast.xml` on the repository's main branch. Automatic checking defaults off, installation requires confirmation, and system profiling is disabled. Feed and archive signatures are required; archive verification precedes extraction. The updater delegate stops audio before installation, and normal app termination also tears down sessions.

The public Ed25519 key is in Info.plist. The private key is stored only in the local login Keychain under Sparkle account `AppMixer`. Never commit private keys, credentials, signing exports or notarization profiles. The bootstrap feed deliberately contains no downloadable release.

## Local packaging

```sh
./scripts/package.sh
```

Creates ad-hoc-signed ZIP/DMG files and SHA-256 checksums in `dist/`. These are development previews, not notarized distribution builds. The DMG includes an Applications shortcut and installation notes.

## Signed release workflow

1. Increment `CFBundleVersion` and `CFBundleShortVersionString`. Build, test, and copy the app to a version-specific staging directory.
2. Sign nested Sparkle components and the app with hardened runtime and timestamps:

   ```sh
   SIGNING_IDENTITY='Developer ID Application: Your Name (TEAMID)' \
     ./scripts/sign-release.sh /absolute/path/to/AppMixer.app
   ```

3. ZIP that exact app and submit it using your local `notarytool` Keychain profile. Wait for **Accepted**, staple the app, and validate with `stapler`, `codesign`, and Gatekeeper. Do not rebuild or modify a submitted binary. A ticket for one version does not cover another.
4. ZIP the stapled app with `ditto -c -k --sequesterRsrc --keepParent`. If distributing a DMG, build/sign/notarize/staple and verify that final DMG too. Update installation notes to accurately describe the artifact's signing status.
5. Generate a candidate update feed from the notarized ZIP:

   ```sh
   ./scripts/prepare-update.sh /absolute/path/to/AppMixer-0.2.0-macOS-arm64.zip 0.2.0
   ```

   This validates the app and generates a signed feed without publishing. Preserve older archives when generating feeds for multiple release versions.
6. Upload the exact archives and checksums to the matching GitHub Release. Download them again and verify SHA-256. Publish the candidate `updates/appcast.xml` **last**. Any subsequent edit to that feed requires re-signing.

The 0.1.0 and 0.2.0 notarization candidates are stored separately in ignored build directories. Neither their credentials nor their binary files belong in Git history.

## Manual acceptance checklist

Use built-in speakers and non-sensitive test audio you choose:

- [ ] At unity gain, no doubled playback, echo or dropout.
- [ ] Lower Chrome without affecting Spotify, then reverse the test.
- [ ] Independent mute/unmute restores the selected slider level.
- [ ] Stop, normal quit and force quit restore original output.
- [ ] Chrome helper and Spotify restart preserve expected grouping/control.
- [ ] Permission denial/revocation produces a recoverable error.
- [ ] Output changes and sleep/wake stop control safely.
- [ ] Long playback has no audible drift/dropouts; measure CPU and latency.
- [ ] Enable/disable login startup, then verify after logout/login.
- [ ] Install a newer notarized release through Sparkle; verify signature checks, cancellation, audio teardown and relaunch.

Synthetic checks and notarization are not substitutes for these tests.
