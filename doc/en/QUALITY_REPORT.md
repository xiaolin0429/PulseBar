English | [简体中文](../zh-CN/QUALITY_REPORT.md)

# PulseBar v1.0 Quality and Validation Report

Last updated: 2026-08-31
Applies to: 1.0.0 (Build 1)
Application-code baseline: `dd74efb`
Conclusion: local engineering and automated release gates pass; multi-device, long-duration, and Apple distribution validation remain

## 1. Evidence boundary

This report records only checks that were actually executed and can be reproduced with repository commands. The following distinctions are mandatory:

- a successful build is not proof of execution on that architecture;
- ad-hoc signing is not Apple distribution signing or notarization;
- a short single-machine run is not an 8/24-hour soak or complete device matrix;
- automated PASS does not replace final product acceptance or App Store review.

## 2. Validation environment

- Mac architecture: Apple Silicon `arm64`.
- macOS: 26.6.2 (25G83).
- Xcode: 26.6 (17F113).
- Swift: 6.
- Minimum deployment target: macOS 13.0.
- Bundle ID: `com.pulsebar.PulseBar`.

## 3. Passed engineering gates

- `swift test`: 38 tests passed, 0 failed.
- `Scripts/verify-release.sh`: complete local automated release gate passed.
- Debug, Release-AppStore, and Release-Direct arm64 builds passed.
- Release-AppStore x86_64 cross-compilation passed; this is not Intel runtime acceptance.
- Release-AppStore passed ad-hoc Hardened Runtime signing and App Sandbox entitlement validation.
- The sandboxed `SystemMetricsProbe` read CPU, VM, swap, network, volume capacity, disk I/O, and adjacent-sample deltas.
- Runtime dependencies are limited to system Frameworks and `/usr/lib`. The offline source-boundary scan passed, and the short run observed no external socket.
- `PrivacyInfo.xcprivacy` is packaged, declares no tracking or collection, and includes required-reason entries for UserDefaults, system uptime, and disk space.
- English and Simplified Chinese onboarding, General, Menu Bar, Monitoring, Privacy & About UI received real UI and accessibility-tree checks.
- App icon, String Catalog, Privacy Policy, Support document, and App Store metadata baseline are present.

## 4. Collector performance

The latest complete gate ran 120 iterations of each Release raw collector:

| Collector | P95 | Budget | Result |
|---|---:|---:|---|
| CPU raw | 0.01 ms | 3 ms | PASS |
| Memory raw | 0.00 ms | 3 ms | PASS |
| Network counters | 0.02 ms | 3 ms | PASS |
| Disk I/O counters | 0.04 ms | 8 ms | PASS |
| Volume capacity (low frequency) | 0.01 ms | 20 ms | PASS |

The sampling coordinator owns lifecycle in one actor and starts all four metric collectors concurrently through structured concurrency. It materializes full snapshots and chart history only while the dashboard is visible.

## 5. Application CPU optimization

Diagnostics showed that requesting Foundation's “available capacity for important usage” URL resource could trigger macOS 26 `CacheDelete` purgeable-space work and several seconds of additional queue activity. The formal capacity path now uses public `statfs` ordinary available blocks:

- 500 volume-capacity iterations improved from P95 6.28 ms to 0.02 ms;
- the menu bar summary and dashboard use independent publication state;
- with adaptive refresh and the dashboard hidden, 60 one-second Release samples averaged 0.280% CPU and peaked at 0.7%;
- six ten-second capacity refreshes in the same window produced no further `CacheDelete` call or double-digit CPU spike;
- the release gate rejects reintroduction of the URL capacity resource key.

## 6. Trend-chart memory optimization

The former Swift Charts path increased physical footprint from about 17 MB to 134–140 MB on hardware, exceeding the 60 MB product budget. The current implementation:

- does not link `Charts.framework` and draws with SwiftUI `Shape` / `Path`;
- reduces each rendered series to at most 60 points;
- preserves local minimum and maximum values in ordered sample buckets;
- uses one sequence range for dual-series charts to avoid time-axis misalignment;
- retains axes, fill, legends, and accessible text summaries.

With the dashboard visible and drawing for 120 seconds:

- physical footprint: first sample 34,657 KB; last 35,665 KB; peak 35,665 KB;
- external sockets: 0;
- CPU, memory, disk, and network single/dual-series trends passed real UI and accessibility checks.

## 7. Resource release after hiding the dashboard

To avoid retaining the post-open graphics footprint:

- hiding the panel clears full snapshots and history arrays from `DashboardPresentationState`;
- a same-size static shell replaces the full card tree;
- the menu bar continues through lightweight `MenuBarPresentationState`;
- hidden-state sampling continues at reduced frequency without materializing chart arrays.

Unit tests, builds, and code-path checks cover this mechanism. A locked-screen environment prevented a reliable final “open, close, then settle while unlocked” footprint measurement. The settled hidden-state value therefore remains a pre-release hardware acceptance item and is not reported as passed.

## 8. Settings window lifecycle regression

The Settings action separates first creation from existing-window activation:

- before a window exists, SwiftUI `OpenSettingsAction` creates the Settings scene;
- once the real `NSWindow` is registered, repeat clicks activate PulseBar and make the window key and frontmost;
- after closing the window, the next click creates it again.

Hardware regression covered first click in a new process, an existing window covered by Finder or the dashboard, and reopening after close. All three displayed one Settings window immediately.

## 9. Five-minute steady-state result

Release-AppStore build, 30-second graphics warm-up, then 300 seconds measured every 10 seconds:

- samples: 30;
- physical footprint: first 33,425 KB; last 33,793 KB; peak 33,873 KB; growth 368 KB;
- observed CPU peak: 6.7%;
- external sockets: 0;
- crashes: 0.

This passes the 60 MB peak and 10 MB steady-growth gates but does not establish an 8-hour or 24-hour result.

## 10. Remaining distribution validation

- 8-hour and 24-hour soak runs, Instruments Energy Log, Idle Wake Ups, Leaks, and Allocations.
- Intel hardware and the complete macOS 13, 14, 15, and current-stable matrix.
- Wi-Fi, Ethernet, VPN, external local volumes, mount/unmount, and real sleep/wake.
- Settled physical-footprint recovery after first open and close while the Mac remains unlocked.
- Apple distribution certificate, Team, provisioning profile, Organizer archive, Privacy Report, notarization, TestFlight, and App Store review.
- Final store screenshots, age rating, copyright owner, and product-owner release approval.

See the [Release Checklist](RELEASE_CHECKLIST.md) for commands and acceptance rules.
