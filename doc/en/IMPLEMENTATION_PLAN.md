English | [简体中文](../zh-CN/IMPLEMENTATION_PLAN.md)

# PulseBar v1.0 Implementation Baseline and Milestone Record

Last updated: 2026-08-31
Status: v1.0 engineering implementation complete; distribution credentials and multi-device acceptance remain

## Delivery objective

Deliver a native macOS 13+ menu bar system monitor according to the [Product Requirements Document](PRD/PulseBar_PRD_v1.0.md) and [Technical Architecture](TS/PulseBar_Technical_Architecture_v1.0.md). v1.0 focuses on CPU, memory, disk, and network. Every collector uses public system APIs, processes data in local memory, requests no administrator access, opens no external network connection, and introduces no third-party runtime dependency.

## Implemented v1.0 scope

- One combined `MenuBarExtra` with Compact, Standard, and Complete densities, module visibility, and drag-to-reorder controls.
- CPU total/user/system usage, logical cores, load averages, and recent trends.
- Memory total, used/available approximations, active/inactive, wired, compressed, purgeable, swap, pressure, and recent trends.
- Local-volume capacity, aggregate disk read/write rates, and recent trends, with independent I/O degradation.
- Primary-network status, download/upload rates, session totals, and recent trends, with baseline rebuilding after interface changes.
- Dashboard, pause/resume, Activity Monitor shortcut, settings, onboarding, recovery, and launch at login.
- Adaptive 1 s/2 s refresh, fixed 1/2/5 s refresh, 60/120/300 s history windows, and sleep/wake handling.
- English, Simplified Chinese, VoiceOver, light/dark/high-contrast UI, App Sandbox, and privacy manifest.
- Lightweight `Shape` / `Path` trends, at most 60 rendered points, and presentation-resource release when the dashboard is hidden.

## Outside v1.0

The following capabilities belong to v1.1 or later and must not be marketed as delivered in v1.0:

- threshold alerts, local notifications, and do-not-disturb policies;
- manual interface selection or simultaneous display of every interface;
- JSON/CSV export and history persisted across launches;
- battery, GPU, temperature, fan, process ranking, or process management.

## Milestones and Git checkpoints

Each engineering milestone was stored as a separate commit after its relevant build and tests passed. The public history was normalized to one commit identity, so commit subjects are the stable milestone identifiers; use `git log --oneline --reverse` for exact hashes.

| Milestone | Commit subject | Status | Main output |
|---|---|---|---|
| Baseline | `chore: establish project baseline` | Complete | Documentation, scope, and repository baseline |
| M0 | `feat: complete milestone 0 system metrics spike` | Complete | API probes, core algorithms, availability report |
| M1 | `feat: complete milestone 1 app skeleton` | Complete | Xcode project, menu bar skeleton, Settings scene, logging |
| M2 | `feat: complete milestone 2 metric collectors` | Complete | Four collectors, concurrent coordination, history, tests |
| M3 | `feat: complete milestone 3 monitoring dashboard` | Complete | Four cards, trends, definitions, pause, shortcuts |
| M4 | `feat: complete milestone 4 settings and integration` | Complete | Persistence, density, ordering, login item, localization |
| M5 | `chore: complete milestone 5 release readiness` | Engineering complete | Accessibility, privacy, Release/Sandbox checks, release documents |

Subsequent experience, performance, and defect fixes remain separate commits, including compact menu-bar layout, Settings window lifecycle, drag ordering, CPU spike reduction, and chart-memory optimization.

## Completion criteria

- Engineering complete: the v1.0 PRD acceptance criteria, TS Definition of Done, and local release gate pass.
- Distribution complete: Apple distribution signing, archive, privacy report, notarization or App Store validation, TestFlight smoke testing, and the supported OS/hardware matrix also pass.
- Items requiring additional hardware or elapsed time—Intel, macOS 13/14/15, and 8/24-hour soak testing—must retain real execution evidence and cannot be replaced by a short single-machine run.

See the [Quality and Validation Report](QUALITY_REPORT.md) for current evidence and the [Release Checklist](RELEASE_CHECKLIST.md) for distribution operations.
