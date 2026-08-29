# PulseBar 隐私政策 / Privacy Policy

更新日期 / Last updated: 2026-08-30

## 中文

PulseBar 的 v1.0 版本完全在本机运行，不收集、上传、出售或共享个人数据。

PulseBar 会读取 CPU、内存、磁盘容量与 I/O、网络接口状态与吞吐等系统指标，以便在菜单栏和监控面板中向用户显示。这些指标只在应用进程的内存中处理；最近趋势使用固定容量内存缓冲区，退出应用后即清除。

用户选择的显示、刷新、语言和启动设置通过 macOS `UserDefaults` 保存在应用自己的沙盒容器中。PulseBar 不读取其他应用的偏好设置。

PulseBar：

- 不创建账户；
- 不包含广告、分析、遥测或崩溃上报 SDK；
- 不建立外部网络连接；
- 不请求管理员、完全磁盘访问或辅助功能权限；
- 不读取文件内容、浏览历史、联系人、位置或其他个人内容。

Mac App Store 隐私标签应申报为 “Data Not Collected”，最终申报必须与待提交二进制的隐私报告一致。

## English

PulseBar v1.0 runs entirely on the Mac. It does not collect, upload, sell, or share personal data.

PulseBar reads system metrics—including CPU, memory, disk capacity and I/O, network-interface status, and throughput—to display them in the menu bar and dashboard. These metrics are processed only in the app's memory. Recent trends use fixed-capacity in-memory buffers and disappear when the app quits.

Display, refresh, language, and launch preferences are stored with macOS `UserDefaults` inside PulseBar's own sandbox container. PulseBar does not read preferences belonging to other apps.

PulseBar:

- does not require an account;
- contains no advertising, analytics, telemetry, or crash-reporting SDK;
- makes no external network connections;
- requests no administrator, Full Disk Access, or Accessibility permission;
- does not read file contents, browsing history, contacts, location, or other personal content.

The intended Mac App Store privacy label is “Data Not Collected.” The final declaration must match the privacy report generated from the submitted binary.
