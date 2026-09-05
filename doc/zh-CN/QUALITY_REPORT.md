[English](../en/QUALITY_REPORT.md) | 简体中文

# PulseBar v1.0 质量与验证报告

更新日期：2026-09-05
适用版本：1.0.0（Build 1）
应用代码基线：原始性能矩阵为 `24e6c27`；关闭路径修复基于 `e058ce2` 的 `codex/fix-dashboard-window-lifecycle`
结论：本地工程与自动化发布门禁通过；冷后台 CPU、可见态内存及独立卡片关闭后的 CPU/展示对象释放达标；快速交互 CPU 峰值、多设备、长时间及 Apple 发行链路仍待执行

## 1. 证据边界

本文只记录已经真实执行并可由仓库命令复现的结果。以下概念严格区分：

- “构建通过”不等同于对应架构的实机运行通过；
- ad-hoc 签名不等同于 Apple 发行签名或公证；
- 单机短时测试不等同于 8/24 小时长稳和完整设备矩阵；
- 自动化 PASS 不替代最终产品验收和 App Store 审核。

## 2. 验证环境

- Mac 架构：Apple Silicon `arm64`。
- macOS：26.6.2（25G83）。
- Xcode：26.6（17F113）。
- Swift：6。
- 最低部署目标：macOS 13.0。
- Bundle ID：`com.pulsebar.PulseBar`。

## 3. 已通过的工程门禁

- `swift test`：38 项测试通过，0 失败。
- `Scripts/verify-release.sh`：完整本地自动化门禁通过。
- Debug、Release-AppStore、Release-Direct 的 arm64 构建通过。
- Release-AppStore 的 x86_64 交叉编译通过；此结果只证明编译，不代表 Intel 实机验收。
- Release-AppStore 使用 ad-hoc Hardened Runtime 签名；签名结构及 App Sandbox entitlement 检查通过。
- 沙盒 `SystemMetricsProbe` 可读取 CPU、VM、Swap、网络、卷容量、磁盘 I/O 和相邻样本差值。
- 运行时依赖仅包含系统 Framework 和 `/usr/lib`；离线源码边界扫描通过；短时运行未观察到外部 socket。
- `PrivacyInfo.xcprivacy` 已打包，声明不跟踪、不收集数据，并包含 UserDefaults、系统启动时间和磁盘空间的用途理由。
- 简体中文和英文的首次启动、通用、菜单栏、监控、隐私与关于界面已完成真机 UI 和可访问性树检查。
- 应用图标、String Catalog、隐私政策、支持文档和 App Store 元数据基线已建立。

## 4. 采集性能

最近一次完整门禁使用 Release 原始采集器执行 120 次基准：

| 采集项 | P95 | 预算 | 结果 |
|---|---:|---:|---|
| CPU raw | 0.01 ms | 3 ms | PASS |
| Memory raw | 0.00 ms | 3 ms | PASS |
| Network counters | 0.02 ms | 3 ms | PASS |
| Disk I/O counters | 0.04 ms | 8 ms | PASS |
| Volume capacity（低频） | 0.01 ms | 20 ms | PASS |

采样协调器在一个 actor 中管理生命周期，并使用结构化并发同时读取四类指标。只有监控面板可见时才物化完整快照和图表历史；独立窗口关闭路径现已显式回到隐藏状态，详见第 7 节。

## 5. 应用自身 CPU 与内存真机矩阵

### 5.1 测量口径

本轮使用 Release-AppStore Universal 包在上述 Apple Silicon 真机上测量，默认自适应刷新、60 秒历史窗口、CPU/内存/网络三个菜单栏模块。除特别说明外，每个场景预热后按一秒间隔采集 20 个样本：

- 通过 `proc_pid_rusage(RUSAGE_INFO_V4)` 读取目标 PulseBar 进程；
- CPU 为相邻样本 `ri_user_time + ri_system_time` 的差值；该值先按本机 `mach_timebase_info` 的 `125/3` 比例由 Mach 时间刻度换算成纳秒，再除以单调墙钟差值，100% 表示占满一个逻辑核心；
- 内存采用 `ri_phys_footprint`，不使用包含大量共享映射的 RSS；
- 结果只统计 PulseBar 进程，不包含 macOS `WindowServer` 的合成开销；
- 线程数取场景结束值，外部 socket 使用 `lsof -nP -a -p <pid> -i` 检查。

各场景在同一个进程中按表格顺序执行，因此中后段内存包含之前绘图和交互产生的进程内缓存；冷启与末尾重启场景是独立的新进程基线。

### 5.2 修复前基线结果（2026-08-31）

| 场景 | 操作与样本 | CPU 平均 / P95 / 峰值 | physical footprint 平均 / 峰值 | 线程 | 外部 socket |
|---|---|---:|---:|---:|---:|
| 冷启后台，仅菜单栏 | 新进程、从未打开卡片，20 秒 | 0.290% / 0.599% / 0.607% | 16.5 / 16.6 MiB | 6 | 0 |
| 卡片前台静置 | 打开后预热 10 秒，再测 20 秒 | 1.724% / 2.065% / 2.108% | 32.6 / 32.7 MiB | 7 | 0 |
| 常规快速滚动与展开/闭合 | 30 秒内执行 8 轮坐标滚动和 16 次展开/闭合，不重复抓取 AX 树 | 7.345% / 12.709% / 13.973% | 38.3 / 38.6 MiB | 7 | 0 |
| 自动化 AX 压力上界 | 30 秒内执行 7 轮交互，每步重新读取完整可访问性树 | 9.500% / 23.580% / 25.310% | 35.1 / 38.6 MiB | 7 | 0 |
| 卡片窗口移动 | 30 秒窗口序列中执行 18 次拖动 | 2.873% / 3.778% / 4.023% | 38.5 / 38.6 MiB | 7 | 0 |
| 卡片打开但被其他应用覆盖 | Finder 前置，预热后测 20 秒 | 2.502% / 2.873% / 2.962% | 38.5 / 38.6 MiB | 7 | 0 |
| 卡片关闭后稳定段 | 关闭后连续测 60 秒，取最后 20 秒 | 2.745% / 3.189% / 3.220% | 38.9 / 39.0 MiB | 6 | 0 |
| 退出并重新冷启，仅菜单栏 | 新进程预热后测 20 秒 | 0.211% / 0.462% / 0.584% | 16.7 / 16.7 MiB | 7 | 0 |

该修复前矩阵表明：冷后台平均 CPU 为 0.290%，满足低于 1% 的产品目标；前台静置平均 1.724%，窗口移动平均 2.873%。常规连续快速交互平均 7.345%、峰值 13.973%，仍存在短时两位数峰值；反复抓取完整 AX 树的自动化压力场景峰值 25.310%，只作为测试上界，不能当作普通鼠标使用数据。旧关闭路径的 CPU 平均为 2.745%，没有回到冷后台水平。可见态 physical footprint 峰值 38.6 MiB，低于 60 MB 产品预算。修复后的关闭结果见第 7 节。

此前 CPU 峰值的根因仍由容量采集路径解释：Foundation 的“重要用途可用容量”URL 资源键会在 macOS 26 触发 `CacheDelete` 可清理空间查询。正式实现改用公开 `statfs` 普通可用块统计后：

- Volume capacity 500 次基准的 P95 从 6.28 ms 降至 0.02 ms；
- 菜单栏摘要与监控面板使用独立发布状态；
- 同一窗口覆盖六次十秒容量刷新，未再观察到 `CacheDelete` 调用；
- 发布门禁包含静态检查，禁止重新引入 URL 容量资源键。

## 6. 趋势图内存优化

旧版 Swift Charts 路径在真机上会将 physical footprint 从约 17 MB 提高到 134–140 MB，超过 60 MB 产品预算。当前实现：

- 不链接 `Charts.framework`，使用 SwiftUI `Shape` / `Path` 直接绘制；
- 每条序列绘制前压缩到最多 60 点；
- 以有序样本桶保留局部最小值和最大值，避免丢失瞬时峰谷；
- 双序列图共享 sequence 范围，避免缺失点造成时间轴错位；
- 保留坐标、填充、双序列图例和完整可访问性摘要。

监控面板持续可见并绘制 120 秒的真机结果：

- physical footprint：首个样本 34,657 KB，末样本 35,665 KB，峰值 35,665 KB；
- 外部 socket：0；
- CPU、内存、磁盘和网络的单/双序列趋势图均通过真机 UI 与可访问性检查。

## 7. 面板隐藏后的资源释放

为避免“打开一次面板后内存长期维持高位”，当前展示状态按可见性拆分：

- 面板隐藏时，`DashboardPresentationState` 清除完整快照和历史数组；
- 完整卡片树被同尺寸静态壳替换，避免 SwiftUI 图形层和 Path 缓存继续保留；
- 菜单栏只订阅轻量 `MenuBarPresentationState`，继续展示必要摘要；
- 采样器继续按隐藏态低频采样，但不再物化或发布图表数组。
- 独立窗口的 `windowWillClose` 显式切回隐藏态、卸载 `contentViewController` 并释放 `AppDelegate` 的窗口引用。

上述机制已通过单元测试、完整发布门禁和 Release-AppStore 真机运行检查。以下表格保留修复前的失败基线：

修复前关闭窗口后的连续 60 秒结果如下：

| 时间点 | physical footprint | PulseBar 进程 CPU |
|---:|---:|---:|
| 1 秒 | 38.8 MiB | 3.035% |
| 5 秒 | 38.8 MiB | 2.749% |
| 10 秒 | 38.8 MiB | 3.317% |
| 20 秒 | 38.9 MiB | 2.548% |
| 30 秒 | 38.8 MiB | 3.018% |
| 45 秒 | 38.8 MiB | 0.162% |
| 60 秒 | 39.0 MiB | 2.914% |

修复前最后 20 秒的 CPU 平均为 2.745%、P95 为 3.189%，physical footprint 平均为 38.9 MiB。修复后使用隔离 bundle 的同一 Release-AppStore 包重新执行冷启、打开、关闭和稳定采样：

| 修复后场景 | 样本 | CPU 平均 / P95 / 峰值 | physical footprint 平均 / 峰值 |
|---|---:|---:|---:|
| 冷启后台、从未打开独立窗口 | 20 秒 | 0.292% / 0.729% / 0.750% | 16.4 / 16.5 MiB |
| 独立窗口关闭后稳定段 | 60 秒，取最后 20 秒 | 0.295% / 0.694% / 0.835% | 31.7 / 31.8 MiB |

补充证据：

- AX 在两次打开/关闭循环后报告 0 个窗口；重新打开会创建新的 `NSWindow`，不会复用已经卸载的 Hosting 内容。
- 多次关闭后的 footprint 分别约为 31.7、32.0 和 31.9 MiB，没有逐轮增长。
- 静默后 heap 中 `NSWindow`、`NSHostingViewBase` 和 `ViewGraphHost` 均为 0，`ViewGraph` 为 6 个，与冷启动相同；发布历史数组保持固定容量。
- 30 秒 Time Profiler 共采到 138 ms CPU，即 0.460%；其中后台采集约 24 ms、菜单栏渲染/更新约 51 ms，Dashboard 调用栈为 0 ms。
- Leaks 冷启动为 14,288 B / 286 个，窗口暖态关闭后为 14,320 B / 287 个；32 B 差异属于系统 `NSXPCConnection` 循环，未出现 PulseBar、Dashboard、窗口或 Hosting 泄漏。

因此 AC-11 在当前硬件上通过：隐藏态 CPU 低于 1%，且完整展示树、Hosting 与窗口对象在静默后释放。physical footprint 仍约为 30–32 MiB，没有回到 16.4 MiB 冷启值；结合对象和泄漏证据，该差异归类为进程暖态的 SwiftUI/AppKit/分配器缓存，而不是完整 Dashboard 树仍被持有。默认菜单栏弹出式卡片仍需按相同口径独立复测，不能用本次独立窗口结果代替。

## 8. 设置窗口生命周期回归

设置按钮将窗口创建与已有窗口前置分别处理：

- 设置场景从未创建时，通过 SwiftUI `OpenSettingsAction` 创建窗口；
- 设置窗口注册真实 `NSWindow` 后，重复点击会先激活应用，再将窗口设为 key 并前置；
- 关闭设置窗口后，再次点击仍可重新创建。

真机回归覆盖：全新进程首次点击；窗口已存在但被 Finder 或监控面板覆盖；关闭窗口后再次点击。三种场景均立即显示设置窗口，且未创建重复窗口。

## 9. 五分钟稳态结果

Release-AppStore 构建，图形预热 30 秒后测量 300 秒，采样间隔 10 秒：

- 样本数：30；
- physical footprint：首个样本 33,425 KB，末样本 33,793 KB，峰值 33,873 KB，增长 368 KB；
- 观察到的 CPU 峰值：6.7%；
- 外部 socket：0；
- 崩溃：0。

该结果通过 60 MB 峰值和 10 MB 稳态增长门禁，但不代表 8 小时或 24 小时长稳通过。

## 10. 待发行阶段验证

- 8 小时与 24 小时长稳，以及 Instruments Energy Log 和 Idle Wake Ups；独立窗口关闭路径的 Allocations、Leaks 与 Time Profiler 已完成。
- Intel 实机，以及 macOS 13、14、15 和当前稳定版的完整矩阵。
- Wi‑Fi、Ethernet、VPN、外接本地卷、挂载/卸载和真实睡眠/唤醒矩阵。
- 使用 Time Profiler 复核常规快速交互的约 14% 峰值，并区分应用布局/绘图、Accessibility 和 `WindowServer` 合成成本。
- 以相同 `proc_pid_rusage` 口径补充默认菜单栏弹出式卡片的打开、关闭与稳定结果。
- Apple 发行证书、Team、Provisioning Profile、Organizer Archive、Privacy Report、公证、TestFlight 和 App Store 审核。
- 最终商店截图、年龄分级、版权主体和产品负责人发行批准。

执行入口与判定规则见[发布清单](RELEASE_CHECKLIST.md)。
