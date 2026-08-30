English | [简体中文](../zh-CN/QUALITY_REPORT.md)

# PulseBar v1.0 Quality and Validation Report

Last updated: 2026-08-31
Applies to: 1.0.0 (Build 1)
Application-code baseline: `24e6c27`
Conclusion: local engineering and automated release gates pass; cold-background CPU and visible-state memory meet budget; rapid-interaction CPU peaks and both CPU and physical-footprint recovery after closing the standalone dashboard still need optimization; multi-device, long-duration, and Apple distribution validation remain

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

The sampling coordinator owns lifecycle in one actor and starts all four metric collectors concurrently through structured concurrency. By design it materializes full snapshots and chart history only while the dashboard is visible; this run found that the standalone-window close path does not return correctly to that hidden state, as detailed in Section 7.

## 5. PulseBar process CPU and memory matrix

### 5.1 Measurement definition

This run used the Release-AppStore Universal package on the Apple Silicon hardware above, with adaptive refresh, a 60-second history window, and the CPU, Memory, and Network menu-bar modules enabled. Unless stated otherwise, each scenario was warmed up and then sampled once per second for 20 samples:

- `proc_pid_rusage(RUSAGE_INFO_V4)` read the target PulseBar process;
- CPU is the adjacent-sample delta of `ri_user_time + ri_system_time`, converted from Mach ticks to nanoseconds using this machine's `mach_timebase_info` ratio of `125/3`, then divided by monotonic wall time; 100% means one fully occupied logical core;
- memory is `ri_phys_footprint`, not RSS with its large shared mappings;
- results cover only the PulseBar process and exclude macOS `WindowServer` composition work;
- thread count is the end-of-scenario value, and external sockets are checked with `lsof -nP -a -p <pid> -i`.

The scenarios ran in table order within one process, so later memory rows include process caches warmed by earlier graphics and interactions. The first cold launch and final relaunch are separate new-process baselines.

### 5.2 Results

| Scenario | Action and sample window | CPU avg / P95 / max | physical footprint avg / max | Threads | External sockets |
|---|---|---:|---:|---:|---:|
| Cold background, menu bar only | New process; dashboard never opened; 20 seconds | 0.290% / 0.599% / 0.607% | 16.5 / 16.6 MiB | 6 | 0 |
| Dashboard foreground and static | Warm for 10 seconds, then sample 20 seconds | 1.724% / 2.065% / 2.108% | 32.6 / 32.7 MiB | 7 | 0 |
| Normal rapid scroll and expand/collapse | Eight coordinate-scroll cycles and 16 toggles over 30 seconds, without repeated AX-tree reads | 7.345% / 12.709% / 13.973% | 38.3 / 38.6 MiB | 7 | 0 |
| Automated AX stress upper bound | Seven interaction cycles over 30 seconds, rereading the full accessibility tree before each action | 9.500% / 23.580% / 25.310% | 35.1 / 38.6 MiB | 7 | 0 |
| Dashboard-window movement | 18 drags during a 30-second window | 2.873% / 3.778% / 4.023% | 38.5 / 38.6 MiB | 7 | 0 |
| Dashboard open but covered | Finder frontmost; warm up, then sample 20 seconds | 2.502% / 2.873% / 2.962% | 38.5 / 38.6 MiB | 7 | 0 |
| Settled after dashboard close | Sample 60 seconds after close; report the last 20 seconds | 2.745% / 3.189% / 3.220% | 38.9 / 39.0 MiB | 6 | 0 |
| Quit and cold relaunch, menu bar only | New process; warm up, then sample 20 seconds | 0.211% / 0.462% / 0.584% | 16.7 / 16.7 MiB | 7 | 0 |

Cold-background CPU averages 0.290%, passing the below-1% product target. Foreground static averages 1.724%, and window movement averages 2.873%. Normal continuous rapid interaction averages 7.345% and peaks at 13.973%, so short double-digit peaks remain. The automated full-AX-tree stress run peaks at 25.310%; it is a testing upper bound, not ordinary mouse-use data. After closing the dashboard, CPU still averages 2.745% instead of returning to the cold-background level. The 38.6 MiB visible-state physical-footprint peak remains below the 60 MB product budget.

The earlier CPU spike was traced to the capacity collector: Foundation's “available capacity for important usage” URL resource can trigger macOS 26 `CacheDelete` purgeable-space work. The formal implementation uses public `statfs` ordinary available blocks:

- 500 volume-capacity iterations improved from P95 6.28 ms to 0.02 ms;
- the menu bar summary and dashboard use independent publication state;
- six ten-second capacity refreshes in the same window produced no further `CacheDelete` call;
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

Unit tests, builds, and code-path checks cover this mechanism. This run completed the previously missing unlocked-hardware “cold launch, open, interact, close, and settle” measurement for the standalone dashboard window.

The 60 seconds immediately after closing the window were:

| Time after close | physical footprint | PulseBar process CPU |
|---:|---:|---:|
| 1 s | 38.8 MiB | 3.035% |
| 5 s | 38.8 MiB | 2.749% |
| 10 s | 38.8 MiB | 3.317% |
| 20 s | 38.9 MiB | 2.548% |
| 30 s | 38.8 MiB | 3.018% |
| 45 s | 38.8 MiB | 0.162% |
| 60 s | 39.0 MiB | 2.914% |

The final 20 seconds averaged 2.745% CPU with P95 3.189%, above the 0.290% cold-background average, so post-close CPU recovery does not pass. Physical footprint averaged 38.9 MiB and peaked at 39.0 MiB, about 22.3 MiB above the same run's 16.5 MiB cold-background average, so footprint recovery also does not pass. Quitting and relaunching restored CPU to a 0.211% average and physical footprint to a 16.7 MiB average.

The formal status is therefore: presentation snapshots and chart arrays have a cleanup mechanism, but neither process CPU nor physical-footprint recovery passes on the standalone-window close path. Because the implementation retains an `NSWindow` whose `isReleasedWhenClosed` is `false`, the result is consistent with SwiftUI content remaining resident and visibility state not returning to background after close; this is an inference from code and measurement, not a substitute for Instruments evidence. Allocations, Leaks, Time Profiler, and memory-graph work must distinguish live objects from SwiftUI/AppKit caches and allocator pages not returned to the OS. The default menu-bar popover path also needs an independent run with the same measurement definition and must not be inferred from this standalone-window result.

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
- Fix and repeat standalone-dashboard CPU and physical-footprint recovery; current settled CPU averages about 2.7% and footprint about 39 MiB versus a roughly 0.3% / 17 MiB cold baseline.
- Use Time Profiler to review the roughly 14% normal rapid-interaction peak and separate app layout/drawing, Accessibility, and `WindowServer` composition costs.
- Add open, close, and settled measurements for the default menu-bar popover using the same `proc_pid_rusage` definition.
- Apple distribution certificate, Team, provisioning profile, Organizer archive, Privacy Report, notarization, TestFlight, and App Store review.
- Final store screenshots, age rating, copyright owner, and product-owner release approval.

See the [Release Checklist](RELEASE_CHECKLIST.md) for commands and acceptance rules.
