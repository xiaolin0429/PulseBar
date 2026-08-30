English | [简体中文](../zh-CN/PRIVACY.md)

# PulseBar Privacy Policy

Effective and last updated: 2026-08-31
Applies to: PulseBar 1.0.x

PulseBar runs entirely on the user's Mac. It does not collect, upload, sell, or share personal data.

## Data processed locally

PulseBar reads system metrics—including CPU, memory, disk capacity and I/O, network-interface status, and throughput—to display them in the menu bar and dashboard. These metrics are processed only in the app's memory. Recent trends use fixed-capacity in-memory buffers and are cleared when the app quits.

Display, refresh, language, and launch preferences are stored with macOS `UserDefaults` inside PulseBar's own sandbox container. PulseBar does not read preferences belonging to other apps.

## What PulseBar does not do

- It does not create or require an account.
- It contains no advertising, analytics, telemetry, or crash-reporting SDK.
- It makes no external network connections.
- It requests no administrator, Full Disk Access, or Accessibility permission.
- It does not read file contents, browsing history, contacts, location, or other personal content.
- It does not write system metrics to long-term history files or cloud services.

## Distribution and project website

The project's source code and documentation are hosted on GitHub. If a user chooses to visit the project website or GitHub Issues, data handling by that website is governed by its provider and the user's settings; it is not runtime data collection by the PulseBar app.

The intended Mac App Store privacy label is “Data Not Collected.” The final declaration must match the Privacy Report generated from the submitted binary.

For privacy questions, contact the maintainers through [GitHub Issues](https://github.com/xiaolin0429/PulseBar/issues). Do not include passwords, tokens, session information, or other sensitive data in a public report.
