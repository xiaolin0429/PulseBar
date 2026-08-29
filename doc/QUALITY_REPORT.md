# PulseBar v1.0 本地质量报告

日期：2026-08-30

## 验证环境

- Mac 架构：arm64。
- macOS：26.6.2（25G83）。
- Xcode：26.6（17F113）。
- 最低部署目标：macOS 13.0。

## 已通过

- `swift test`：24 项测试通过，0 失败。
- `Scripts/verify-release.sh`：完整自动化门禁通过。
- Debug、Release-AppStore、Release-Direct arm64 构建通过。
- Release-AppStore x86_64 交叉编译通过；此结果仅证明编译，不等同 Intel 实机运行验收。
- Release-AppStore 使用 ad-hoc Hardened Runtime 签名，签名校验与 App Sandbox entitlement 检查通过。
- 沙盒 `SystemMetricsProbe`：CPU、VM、Swap、网络、卷容量、磁盘 I/O 与一秒差值全部可读取。
- 运行时依赖只包含系统 Framework 与 `/usr/lib`；源码离线边界扫描通过；短时运行未观察到外部 socket。
- `PrivacyInfo.xcprivacy` 已打包，申报不跟踪、不收集数据，并声明 UserDefaults、系统启动时间与磁盘空间的用途理由。
- 简体中文和英文首启、通用、菜单栏、监控、隐私与关于页面完成真实 UI 与可访问性树检查。
- 应用图标、String Catalog、隐私政策、支持文档和 App Store 元数据草案已完成。

## 采集性能

120 次 Release 原始采集基准的最近一次完整门禁结果：

| 采集项 | P95 | 预算 | 结果 |
|---|---:|---:|---|
| CPU raw | 0.01 ms | 3 ms | PASS |
| Memory raw | 0.00 ms | 3 ms | PASS |
| Network counters | 0.01 ms | 3 ms | PASS |
| Disk I/O counters | 0.05 ms | 8 ms | PASS |
| Volume capacity（低频） | 6.70 ms | 20 ms | PASS |

采样协调器并发执行四类采集；面板关闭时不物化图表数组，也不向 SwiftUI 发布完整快照。

## 短时长稳脚本自检

20 秒、2 秒采样间隔、Release-AppStore 构建：

- 10 个样本；
- physical footprint：首尾均 17,280 KB，峰值 17,280 KB；
- 观察到的 CPU 峰值：0.2%；
- 外部 socket：0；
- 崩溃：0。

这只验证脚本、测量口径和明显回归，不代表 AC-10 的 8 小时结论。

## 尚需发布阶段执行

- 8 小时与 24 小时长稳、Energy Log、Idle Wake Ups、Leaks / Allocations。
- Intel 实机，以及 macOS 13、14、15 和当前稳定版的完整矩阵。
- Wi‑Fi、Ethernet、VPN、外接卷与真实睡眠/唤醒矩阵。
- Apple 发行证书、Team、Provisioning Profile、Organizer Archive、Privacy Report、公证、TestFlight 与 App Store 审核。
- 公开支持 URL、隐私政策 URL、最终商店截图和版权主体。

这些项目依赖额外硬件、时间或 Apple 开发者资质，不能由单机短时自动化替代；执行命令与验收项见 `doc/RELEASE_CHECKLIST.md`。
