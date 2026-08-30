English | [简体中文](../../zh-CN/TS/Milestone_0_API_Availability_Report.md)

# PulseBar v1.0 System Metrics API Availability Report

First validated: 2026-08-29
Last updated: 2026-08-31
Status: Milestone 0 complete; APIs are part of the formal v1.0 implementation

## 1. Objective

Validate the public macOS APIs required for CPU, memory, volume capacity, disk I/O, and network metrics under App Sandbox with no network entitlement, administrator access, or privileged helper, and establish performance and degradation baselines.

## 2. Validation environment

- Architecture: Apple Silicon `arm64`.
- System: macOS 26.6.2 (Build 25G83).
- Toolchain: Apple Swift 6.3.3 and Xcode 26.6.
- Runtime form: Release build in a temporary `.app` bundle, ad-hoc signed, App Sandbox enabled, no network entitlement.

## 3. API conclusions

| Capability | Formal API | Result | Key conclusion |
|---|---|---|---|
| CPU ticks | `host_processor_info` | PASS | Logical-processor ticks support total and user/system deltas |
| VM statistics | `host_statistics64` / `host_page_size` | PASS | Page counters support memory breakdown and usage |
| Swap | `sysctlbyname(vm.swapusage)` | PASS | Total, used, and available values are readable |
| Memory pressure | `DispatchSourceMemoryPressure` | PASS | System pressure events supplement VM values |
| Network counters | `getifaddrs` | PASS | Interface byte counters are readable; SystemConfiguration resolves the primary interface |
| Volume enumeration | `FileManager.mountedVolumeURLs` and URL metadata | PASS | Local volumes expose identifiers, names, and device attributes |
| Volume capacity | Darwin `statfs` | PASS | Total and ordinary available blocks avoid purgeable-space scanning |
| Disk I/O | IOKit `IOBlockStorageDriver` Statistics | PASS | Adjacent cumulative counters produce read/write rates |
| Adjacent samples | Monotonic-clock delta | PASS | CPU, disk, and network deltas work; resets and rollbacks rebuild baselines |

## 4. Current performance baseline

Release raw collectors, 120 iterations:

| Collector | P95 | Budget |
|---|---:|---:|
| CPU raw | 0.01 ms | 3 ms |
| Memory raw | 0.00 ms | 3 ms |
| Network counters | 0.02 ms | 3 ms |
| Disk I/O counters | 0.04 ms | 8 ms |
| Volume capacity (low frequency) | 0.01 ms | 20 ms |

These are reproducible observations on the current machine, not absolute guarantees for every device. Volume enumeration and capacity live on a low-frequency path and are not repeated for every one-second snapshot.

## 5. Key implementation decisions

### 5.1 Ordinary available capacity

An early experiment used Foundation's “available capacity for important usage” key. On macOS 26 it could trigger `CacheDelete` purgeable-space work and visible CPU spikes. The formal implementation uses public `statfs`:

- total: `f_blocks * f_bsize`;
- ordinary available: `f_bavail * f_bsize`;
- overflow-safe integer arithmetic;
- UI copy explains that Finder's purgeable-space definition may differ.

The release gate rejects reintroduction of the related URL capacity key.

### 5.2 Delta metrics

CPU ticks, disk I/O, and network bytes are cumulative counters. The implementation:

- uses the first sample only to establish a baseline;
- measures elapsed time with a monotonic clock;
- rebuilds the baseline after interface changes, sleep/wake, rollbacks, or invalid intervals;
- displays a warming state instead of a false zero or spike;
- rejects NaN, infinity, and negative rates or percentages.

### 5.3 Independent degradation

One API failure does not disable unrelated modules:

- volume capacity remains when disk I/O is unavailable;
- an unresolved primary network interface shows offline or warming without adding false session traffic;
- base VM metrics remain if memory-pressure events are unavailable;
- technical context is written only to local Unified Logging.

## 6. Sandbox validation

`Scripts/verify-sandbox-probe.sh` builds the Release probe, places it in a temporary `.app` bundle, applies `com.apple.security.app-sandbox = true`, verifies signing, and runs it. All formal metrics are readable without Incoming or Outgoing Network entitlements.

A bare Mach-O executable with an App Sandbox entitlement may be rejected because it lacks an application-bundle context. Sandbox conclusions must therefore come from the `.app` probe.

## 7. Remaining distribution matrix

- Intel x86_64 hardware;
- macOS 13, 14, 15, and current stable;
- Wi-Fi, Ethernet, VPN, offline, and primary-interface changes;
- external SSD, removable storage, local-volume mount and unmount;
- real sleep/wake baseline rebuilding;
- 8/24-hour stability, leaks, and energy.

These items require matching hardware or elapsed time and are not replaced by a short single-machine probe. Track them in the [Release Checklist](../RELEASE_CHECKLIST.md).
