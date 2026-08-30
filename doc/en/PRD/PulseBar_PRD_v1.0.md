English | [简体中文](../../zh-CN/PRD/PulseBar_PRD_v1.0.md)

# PulseBar Product Requirements Document (PRD) v1.0

Product: PulseBar
Document version: 1.0
Last updated: 2026-08-31
Product status: v1.0 engineering implementation baseline
Distribution status: local quality gate passed; multi-device, long-duration, and Apple distribution work remains

## 1. Purpose

This document defines the formal v1.0 product scope, interaction model, measurement definitions, non-functional targets, and acceptance criteria for PulseBar. Implementation, testing, store copy, and future changes use this document as the product baseline.

Related documents:

- [Technical Architecture](../TS/PulseBar_Technical_Architecture_v1.0.md)
- [Implementation Baseline and Milestones](../IMPLEMENTATION_PLAN.md)
- [Quality and Validation Report](../QUALITY_REPORT.md)
- [Release Checklist](../RELEASE_CHECKLIST.md)
- [Privacy Policy](../PRIVACY.md)

## 2. Product definition

PulseBar is a native macOS menu bar system monitor. One compact menu bar item presents essential status continuously; clicking it opens CPU, memory, disk, and network details with recent trends.

### 2.1 Goals

- Let users judge whether the Mac is busy without opening Activity Monitor.
- Communicate several essential metrics within limited menu bar space.
- Make measurement definitions explicit and never disguise unavailable data as zero.
- Keep PulseBar's own CPU, memory, wake-up, and network footprint extremely low.
- Use public system APIs and remain compatible with App Sandbox.

### 2.2 Product principles

1. **Small and focused**: resident cost must remain proportional to the utility provided.
2. **Readable at a glance**: prioritize status over redundant labels.
3. **Local first**: process metrics in memory, never upload them, and do not persist history across launches.
4. **Honest degradation**: warming, stale, failed, and unsupported states remain distinct.
5. **Native behavior**: follow macOS conventions for menu bar items, Settings, login items, and accessibility.
6. **Explicit boundaries**: the public repository distinguishes shipped functionality from future planning.

## 3. Target users and scenarios

### 3.1 Target users

- Mac users who want continuous awareness of system load;
- developers, designers, media professionals, and data workers;
- users who need short-term performance context without a full diagnostic suite;
- privacy-conscious users who value no ads and low resource usage.

### 3.2 Core scenarios

- Check CPU and memory pressure during compilation, rendering, or meetings.
- Observe network throughput during downloads, sync, or VPN changes.
- Review system-data and local-volume capacity before disk space becomes critical.
- Open the dashboard after a spike to inspect the last 60 seconds to 5 minutes.
- Reduce density, hide modules, or reorder them when menu bar space is constrained.

## 4. Version scope

### 4.1 Formal v1.0 scope

- One combined menu bar item.
- CPU, memory, disk, and network modules.
- Compact, Standard, and Complete menu bar densities.
- Module toggles, vertical drag ordering, and one-decimal option.
- Detailed dashboard with in-memory trends.
- Pause/resume, Activity Monitor shortcut, and Quit.
- Adaptive and fixed refresh policies.
- 60-second, 2-minute, and 5-minute history windows.
- Capacity and rate unit settings.
- Launch at login, Dock icon, and reopen behavior.
- English, Simplified Chinese, VoiceOver, light/dark/high-contrast UI.
- Onboarding, menu bar recovery, and Privacy & About information.

### 4.2 Not included in v1.0

- threshold alerts, local notifications, and do-not-disturb;
- persistent history, cross-launch storage, or CSV/JSON export;
- manual network-interface selection or all-interface display;
- battery, GPU, temperature, fan, or sensor metrics;
- process rankings, termination, or other process management;
- cloud sync, accounts, remote monitoring, or team features.

Store copy must not describe these items as delivered v1.0 capabilities.

## 5. Information architecture

PulseBar has five user-visible entry points:

1. **Menu bar summary**: continuously displays selected modules.
2. **Dashboard**: opens from the menu bar item and presents complete status.
3. **Settings**: General, Menu Bar, Monitoring, and Privacy & About tabs.
4. **Onboarding**: explains menu bar location, privacy, and basic use.
5. **Recovery**: restores a menu bar item removed by the system or user.

## 6. Menu bar summary

### 6.1 General requirements

- Create exactly one `MenuBarExtra`.
- Default modules are CPU, Memory, and Network.
- Keep at least one module visible.
- Preserve module order across launches.
- Disable implicit menu bar animation to prevent numeric updates from shifting.
- Let users choose Compact density or fewer modules when space is limited.
- VoiceOver announces complete semantic content rather than visual abbreviations.

### 6.2 Density

| Density | Layout | Content |
|---|---|---|
| Compact | One line, 11 pt rounded monospaced digits | Each module's primary value |
| Standard | Two-line, 8 pt monospaced semibold template image | Compact multi-column CPU, memory, and network |
| Complete | Two-line template image | Standard capabilities plus optional Disk |

Standard and Complete render a bounded template image to control two-line font, spacing, and width reliably inside `MenuBarExtra`. Disk appears only in Complete density, and Settings must explain this rule.

### 6.3 Module expression

- CPU: percentage; bottom label CPU in two-line mode.
- Memory: percentage; bottom label MEM in two-line mode.
- Network: download and upload; Compact prioritizes download.
- Disk: ordinary available capacity on the primary volume; bottom label SSD.
- Unavailable values use an em dash instead of a false zero.
- Severity may change foreground color, but status must not rely on color alone.

## 7. Dashboard

### 7.1 Layout

- Fixed 420 pt width and adaptive 500–720 pt height.
- Header: device name, monitoring state, last update, and system uptime.
- Header actions: pause/resume and Settings.
- Scroll area: CPU, Memory, Disk, and Network cards.
- Footer: Activity Monitor and Quit.

### 7.2 Card rules

Each card includes:

- module name and icon;
- primary metric;
- required breakdown;
- recent trend;
- expandable measurement definition;
- warming, stale, or unavailable state.

Expanding or collapsing a definition must move the card and chart through the same layout animation without transient misalignment.

### 7.3 Settings action

- The first click creates and displays Settings.
- If Settings exists but another app covers it, another click activates PulseBar and brings the window to front.
- After Settings closes, another click recreates it.
- No path creates duplicate Settings windows.

## 8. Metrics and definitions

### 8.1 CPU

Display:

- total usage;
- user and system usage;
- logical-core count;
- 1-, 5-, and 15-minute load averages;
- recent total-usage trend.

Definition:

- read cumulative per-core ticks with `host_processor_info`;
- use adjacent-sample deltas for user, system, nice, and idle;
- total usage equals non-idle delta divided by total delta;
- the first sample only establishes a baseline and shows warming;
- rebuild after counter or interval anomalies and never output NaN, a negative value, or more than 100%.

### 8.2 Memory

Display:

- physical total;
- approximate used and available;
- active, inactive, wired, compressed, and purgeable;
- swap used and total;
- normal, warning, critical, or unknown pressure;
- recent used-ratio trend.

Definition:

- read VM page counters with `host_statistics64` and `host_page_size`;
- read swap with `sysctlbyname(vm.swapusage)`;
- use system memory-pressure events;
- describe “used” as a trend-oriented approximation rather than byte-for-byte Activity Monitor parity;
- provide an in-app explanation for different sampling windows and definitions.

### 8.3 Disk

Display:

- system data volume and local-volume name, total, ordinary available, and used ratio;
- aggregate device read and write rates;
- recent read/write trends;
- capacity even when I/O is unavailable.

Definition:

- enumerate local volumes with `FileManager.mountedVolumeURLs` and public URL metadata;
- read total and ordinary available blocks with Darwin `statfs`;
- never request “available capacity for important usage” or trigger purgeable-space scanning;
- explain that Finder's purgeable-space definition may differ;
- derive I/O rates from adjacent IOKit block-storage counters;
- refresh capacity only on a low-frequency path or configuration change.

### 8.4 Network

Display:

- online, offline, requires connection, or unknown path state;
- automatically selected primary-interface name and kind;
- download and upload rates;
- download and upload totals for the current app session;
- recent download/upload trends.

Definition:

- `NWPathMonitor` provides path state;
- SystemConfiguration resolves the system primary interface;
- `getifaddrs` reads cumulative interface bytes;
- interface switches, rollbacks, sleep/wake, or invalid intervals rebuild the baseline;
- session totals remain in memory and clear on app exit;
- v1.0 does not provide manual interface selection.

## 9. Sampling, history, and lifecycle

### 9.1 Refresh policy

| Policy | Dashboard visible | Dashboard hidden |
|---|---:|---:|
| Adaptive | 1 s | 2 s |
| Every 1 second | 1 s | 1 s |
| Every 2 seconds | 2 s | 2 s |
| Every 5 seconds | 5 s | 5 s |

Requirements:

- Start all four metric collectors concurrently in one sampling round.
- One coordinator owns the sampling lifecycle.
- Use a 10% timer tolerance to reduce unnecessary wake-ups.
- Cancel the loop during pause or sleep.
- Rebuild delta baselines before resuming after pause or wake.

### 9.2 History

- Each series uses a fixed-capacity 360-element ring buffer.
- Users choose a 60-, 120-, or 300-second display window.
- Materialize and publish history arrays only while the dashboard is visible.
- Reduce each rendered series to at most 60 points while preserving ordered local extrema.
- Never persist, upload, or carry history across launches.

### 9.3 Hidden dashboard

After the dashboard closes:

- clear full snapshot and history-array presentation state;
- unload full cards and chart views, replacing them with a same-size static shell;
- continue the menu bar through a lightweight summary;
- stop materializing chart arrays for hidden UI.

## 10. Settings requirements

### 10.1 General

- Launch at login, default off.
- Show Dock icon, default off.
- Reopen with menu bar only or also show the dashboard.
- Language: Follow System, Simplified Chinese, or English.
- Restore defaults after confirmation.
- Explain when login-item approval is required or unavailable in the current build.

### 10.2 Menu Bar

- Live preview.
- Compact, Standard, and Complete densities.
- Optional one-decimal display.
- CPU, Memory, Disk, and Network toggles.
- Vertical full-row ordering through the right-side handle.
- Drag visuals follow only the Y axis.
- Switches remain aligned.
- Context-menu Move Up/Move Down and accessibility-adjustable alternatives.

### 10.3 Monitoring

- Adaptive, 1 s, 2 s, or 5 s refresh.
- 60-second, 2-minute, or 5-minute history.
- Mixed default, decimal SI, or binary IEC units.
- Automatically selected system primary network interface.
- System data volume as the default disk.
- Pause during sleep as a fixed safe behavior.

### 10.4 Privacy & About

- State no collection and no external network connection.
- Show that administrator, Full Disk Access, and Accessibility permissions are not required.
- Show version and public system-API sources.
- Do not expose alert settings that are not implemented.

## 11. State, errors, and recovery

Every module uses one state model:

- `available`: valid current data;
- `warmingUp`: establishing a delta baseline;
- `stale`: recent valid value retained with age;
- `unavailable`: stable error code, user-message key, and local debug context.

Requirements:

- one module failure does not stop another;
- first-screen copy remains concise and hides technical diagnostics;
- pause state is explicit and recoverable;
- a removed menu bar item causes a recovery entry point on the next launch;
- persisted settings are normalized, and an empty module list restores at least one module.

## 12. Accessibility and localization

- Formal languages are English and Simplified Chinese; Follow System uses the current locale.
- Every user-visible string belongs in String Catalog.
- Menu bar summary, charts, actions, toggles, and states have VoiceOver labels.
- Charts provide textual summaries instead of requiring line interpretation.
- Reordering offers adjustable accessibility actions and a context menu.
- Support keyboard navigation, light/dark, increased contrast, and reduced motion.
- Critical text must not truncate in either formal language.

## 13. Privacy and security

- Enable App Sandbox.
- Do not enable Incoming or Outgoing Network entitlement.
- Request no administrator, Full Disk Access, or Accessibility permission.
- Do not read file contents or data belonging to other apps.
- Include no ad, analytics, telemetry, crash-upload, or third-party runtime SDK.
- Store settings only through `UserDefaults` in the app sandbox.
- Keep metrics and history in memory.
- Match final App Store declarations to the archive's Privacy Report.

## 14. Non-functional targets

### 14.1 Performance budgets

- One raw collection round must be far below the refresh interval; log a local notice above 20 ms.
- P95 budgets: CPU 3 ms, Memory 3 ms, Network 3 ms, Disk I/O 8 ms, low-frequency Volume 20 ms.
- Adaptive hidden-dashboard resident CPU target is below 1%; document isolated scheduler noise separately.
- Visible-dashboard physical footprint peak is below 60 MB.
- Five-minute steady-state growth is at most 10 MB.
- Hidden dashboard retains neither the full graphics tree nor published history arrays.

### 14.2 Stability

- Eight-hour adaptive operation has no crash, persistent growth, or unexpected external connection.
- A 24-hour run is required for release-candidate observation.
- Resume within five seconds of wake without a false rate spike.
- Volume and network-interface changes do not disable the application.

### 14.3 Compatibility

- Minimum macOS 13.
- Build for `arm64` and `x86_64`.
- Before distribution, cover macOS 13, 14, 15, current stable, and at least one Intel Mac.
- Current x86_64 evidence is cross-compilation only, not hardware acceptance.

## 15. Acceptance criteria

| ID | Acceptance | v1.0 engineering status |
|---|---|---|
| AC-01 | Cold launch inserts one menu bar item and updates the default three modules | Implemented |
| AC-02 | Density, visibility, decimals, and order persist correctly | Implemented |
| AC-03 | Four cards show formal values and state semantics | Implemented |
| AC-04 | 60/120/300 s trends use fixed memory and at most 60 rendered points | Implemented |
| AC-05 | Pause/resume and sleep/wake rebuild delta baselines | Implemented |
| AC-06 | Settings first-open, bring-to-front, and reopen-after-close work | Implemented and hardware-regressed |
| AC-07 | Reorder handle moves the complete row only vertically | Implemented and hardware-regressed |
| AC-08 | Definition expansion moves card and chart smoothly together | Implemented and hardware-regressed |
| AC-09 | Sandbox, no external connection, and no collection boundaries hold | Local gate passed |
| AC-10 | Visible graphics stay below 60 MB and five-minute growth below 10 MB | Passed on current hardware |
| AC-11 | Hidden dashboard releases full presentation resources and reaches target recovery | Standalone-window hardware result fails: post-close CPU averages 2.745% and footprint 38.9 MiB instead of the 0.290% / 16.5 MiB cold baseline |
| AC-12 | 8-hour, OS/device matrix, and Apple distribution chain | Distribution-stage pending |

## 16. Version and distribution status

| Stage | Scope | Status |
|---|---|---|
| A | API availability, sandbox, and performance probes | Complete |
| B | v1.0 functionality, experience, defect fixes, and local gate | Complete |
| C | Multi-device, multi-OS, 8/24-hour, and Instruments | Pending |
| D | Apple signing, archive, Privacy Report, TestFlight/App Store | Pending |

PulseBar can claim distribution complete only after applicable Stage C and D work passes and the product owner approves release.

## 17. Store and support

- Formal store copy: [App Store Metadata](../APP_STORE_METADATA.md).
- Privacy statement: [Privacy Policy](../PRIVACY.md).
- Support: [GitHub Issues](https://github.com/xiaolin0429/PulseBar/issues).
- Public reports must not include passwords, cookies, tokens, sessions, or personal file contents.

## 18. Confirmed product decisions

1. Minimum system is macOS 13.
2. Use one combined `MenuBarExtra`, not one item per metric.
3. v1.0 keeps only recent in-memory history.
4. Trends use SwiftUI `Shape` / `Path`, not Swift Charts.
5. Disk capacity uses `statfs` ordinary available blocks without purgeable-space calculation.
6. Four collectors execute concurrently within one round.
7. Alerts and notifications belong to v1.1 and are not linked into v1.0 runtime.
8. Metric failures degrade independently and never masquerade as zero.
9. Public repository: <https://github.com/xiaolin0429/PulseBar>.
