English | [简体中文](../zh-CN/RELEASE_CHECKLIST.md)

# PulseBar v1.0 Release Checklist

Last updated: 2026-08-31
Applies to: 1.0.0 (Build 1)

This checklist separates locally verified work from items that require a real distribution environment:

- `[x]`: reproducible evidence exists;
- `[ ]`: not executed or must be reconfirmed against the final archive;
- a successful build alone must not mark an unexecuted item complete.

## 1. Local automated gate

Canonical entry point:

```bash
Scripts/verify-release.sh
```

Verified:

- [x] 38 Swift unit tests pass.
- [x] String Catalog and privacy manifest exist and are packaged.
- [x] Raw-collector P95 budgets pass.
- [x] Debug and Release-AppStore arm64 builds pass.
- [x] Release-AppStore x86_64 cross-compilation passes.
- [x] Ad-hoc Hardened Runtime signing and App Sandbox entitlements pass.
- [x] Runtime dependency, offline-source-boundary, and short external-socket checks pass.
- [x] The sandboxed system-metrics probe passes.
- [x] Repository hygiene passes and package artifacts are not tracked.

## 2. Local Universal package

Package after the complete gate:

```bash
Scripts/package-local-release.sh --verify
```

Omit `--verify` for a fast rebuild; add `--launch` to relaunch `dist/PulseBar.app`.

- [x] The script creates an `arm64 + x86_64` Universal `.app` and ZIP.
- [x] It validates architecture, signing, sandboxing, resources, dependencies, and extracted ZIP contents.
- [ ] Regenerate the final candidate from a clean worktree, target version tag, and final documentation commit.
- [ ] Never label a local ad-hoc build as notarized or App Store-ready.

## 3. Functionality and experience

Locally verified baseline:

- [x] Three menu bar densities, module visibility, and persisted ordering.
- [x] The right-side handle drags the complete row and movement is constrained vertically.
- [x] Module switches align, at least one module remains, and Disk appears only in Complete density.
- [x] Settings first creation, bring-to-front after being covered, and recreation after close.
- [x] Expanding/collapsing measurement definitions moves the card and trend together.
- [x] Pause/resume, Activity Monitor, onboarding, and recovery.
- [x] English, Simplified Chinese, and primary accessibility-tree checks.

Reconfirm on the final candidate:

- [ ] No truncation, overlap, misalignment, incorrect animation, or menu bar overflow.
- [ ] VoiceOver fully announces summaries, buttons, charts, and states.
- [ ] Keyboard navigation, increased contrast, reduced motion, light, and dark appearance.
- [ ] Low disk, memory pressure, collection failure, warming, and stale states.
- [ ] Product owner grants final release acceptance.

## 4. Memory, CPU, and soak

- [x] Visible chart run stays below 60 MB for 120 seconds; last sample 35,665 KB.
- [x] Five-minute steady state peaks at 33,873 KB and grows 368 KB, with no crash or external socket.
- [x] Dashboard-hidden 60-second CPU averages 0.280% and peaks at 0.7%.
- [x] Hiding the dashboard clears full snapshot/history presentation state and unloads the full card tree.
- [ ] While unlocked, repeat first open, close, and settled physical-footprint recovery.
- [ ] 8-hour adaptive run: `Scripts/soak-test.sh 28800 30`.
- [ ] 24-hour adaptive run: `Scripts/soak-test.sh 86400 60`.
- [ ] Record CPU, physical footprint, Energy Impact, and Idle Wake Ups with the dashboard hidden and visible.
- [ ] Validate 1 s, 2 s, and 5 s policies with Instruments Energy Log.
- [ ] Run key energy scenarios on AC power and battery.
- [ ] Use Xcode Leaks / Allocations to inspect Mach, IOKit, `getifaddrs`, and graphics lifetimes.

A short soak validates the script and catches obvious regressions; it does not replace an 8/24-hour conclusion.

## 5. OS and hardware matrix

- [ ] Apple Silicon on macOS 13.
- [ ] Apple Silicon on macOS 14.
- [ ] Apple Silicon on macOS 15.
- [ ] Apple Silicon on the current stable release.
- [ ] Intel x86_64 on at least one supported macOS release.
- [ ] Wi-Fi, Ethernet, VPN, offline, and interface switching.
- [ ] APFS system volume, external local volume, mount, and unmount.
- [ ] Resume within five seconds of wake without a false rate spike.

## 6. Apple distribution and store submission

- [ ] Apple Developer Team, Bundle ID, certificate, and provisioning profile are configured.
- [ ] Xcode Organizer archives the final version from a clean commit.
- [ ] Organizer Privacy Report matches `PrivacyInfo.xcprivacy`, the [Privacy Policy](PRIVACY.md), and “Data Not Collected.”
- [ ] Final binary contains no external connection, unexpected SDK, or private Framework.
- [ ] Developer ID distribution passes notarization and Gatekeeper, or Mac App Store validation passes.
- [ ] TestFlight for Mac installation, launch, Settings, and core-metric smoke tests pass.
- [ ] Screenshots, description, keywords, age rating, copyright, and URLs in [App Store Metadata](APP_STORE_METADATA.md) are confirmed.
- [ ] Version, build number, Git tag, and archive record agree.
- [ ] Product owner approves release.

Local ad-hoc signing proves only the current signature structure, sandbox entitlement, and runtime behavior. It does not replace Apple distribution signing, notarization, TestFlight, or App Store review.
