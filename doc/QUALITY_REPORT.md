# PulseBar v1.0 质量与验证报告

更新日期：2026-08-31
适用版本：1.0.0（Build 1）
应用代码基线：`dd74efb`
结论：本地工程与自动化发布门禁通过；多设备、长时间及 Apple 发行链路仍待执行

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
| Network counters | 0.01 ms | 3 ms | PASS |
| Disk I/O counters | 0.04 ms | 8 ms | PASS |
| Volume capacity（低频） | 0.02 ms | 20 ms | PASS |

采样协调器在一个 actor 中管理生命周期，并使用结构化并发同时读取四类指标。只有监控面板可见时才物化完整快照和图表历史。

## 5. 应用自身 CPU 优化

真机诊断确认：以 Foundation URL 资源键请求“重要用途可用容量”会在 macOS 26 触发 `CacheDelete` 的可清理空间查询，并产生持续数秒的额外队列工作。当前容量路径改为公开 `statfs` 普通可用块统计：

- Volume capacity 500 次基准的 P95 从 6.28 ms 降至 0.02 ms；
- 菜单栏摘要与监控面板使用独立发布状态，避免一次采样使顶层应用、设置页和全部图表共同失效；
- 默认自适应策略、面板关闭时，Release 真机 60 个一秒样本的平均 CPU 为 0.280%，峰值为 0.7%；
- 同一窗口覆盖六次十秒容量刷新，未再观察到 `CacheDelete` 调用或两位数 CPU 尖峰；
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

该实现已通过单元测试、构建和代码路径检查。锁屏环境下无法可靠完成“解锁后真实打开—关闭面板”的终态 footprint 采样，因此“隐藏后稳定回落水平”仍列入发行前真机验收，不在本文中虚报数值。

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

- 8 小时与 24 小时长稳，以及 Instruments Energy Log、Idle Wake Ups、Leaks 和 Allocations。
- Intel 实机，以及 macOS 13、14、15 和当前稳定版的完整矩阵。
- Wi‑Fi、Ethernet、VPN、外接本地卷、挂载/卸载和真实睡眠/唤醒矩阵。
- 面板首次打开、关闭并稳定后的 physical footprint 回落验收。
- Apple 发行证书、Team、Provisioning Profile、Organizer Archive、Privacy Report、公证、TestFlight 和 App Store 审核。
- 最终商店截图、年龄分级、版权主体和产品负责人发行批准。

执行入口与判定规则见[发布清单](RELEASE_CHECKLIST.md)。
