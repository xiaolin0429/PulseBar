English | [简体中文](../zh-CN/SUPPORT.md)

# PulseBar Support and Known Limitations

Last updated: 2026-08-31
Applies to: PulseBar 1.0.x

## Getting support

Use [GitHub Issues](https://github.com/xiaolin0429/PulseBar/issues) for defects and feature requests. Search existing issues first and provide reproducible diagnostic context without sensitive information.

For a potential security or privacy concern, describe only the impact, affected version, and a safe reproduction boundary. Never paste passwords, cookies, tokens, sessions, personal file content, or personally identifiable information into a public issue.

## Support scope

- Minimum system: macOS 13.
- Architecture targets: Apple Silicon `arm64` and Intel `x86_64`. Actual distribution support follows the device acceptance status in the [Release Checklist](RELEASE_CHECKLIST.md).
- Data sources: public system APIs, with no command-line collector process, private framework, or privileged helper.
- Formal feature scope: CPU, memory, disk, network, recent in-memory trends, menu bar summary, and local settings.

## Known limitations

- PulseBar and Activity Monitor use different sampling windows and memory definitions. Instantaneous values may differ even when longer trends agree.
- Some hardware or sandbox environments may not expose IOKit disk counters. Capacity remains available while I/O rates independently degrade.
- PulseBar reports ordinary available filesystem blocks. APFS snapshots, purgeable space, and Finder presentation may produce different values.
- VPN changes, interface switches, sleep/wake, and counter rollbacks rebuild rate baselines. Rates temporarily show a warming state rather than a false spike.
- macOS may temporarily hide a menu bar item when space is constrained. Reduce modules, choose Compact density, or reopen the app to restore the item.
- v1.0 does not include alerts, notifications, persistent history, export, process rankings, temperature, GPU, or fan metrics.

## Recommended defect report

Include, when possible:

- macOS version, Mac model, and chip architecture;
- PulseBar version, build number, and installation source;
- affected module, refresh policy, and reproduction steps;
- expected and actual results;
- whether VPN, external storage, sleep/wake, network switching, or low disk space is involved;
- screenshots or log excerpts confirmed to contain no personal information.

Project home: <https://github.com/xiaolin0429/PulseBar>
