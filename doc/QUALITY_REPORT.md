# PulseBar v1.0 本地质量报告

日期：2026-08-30

## 验证环境

- Mac 架构：arm64。
- macOS：26.6.2（25G83）。
- Xcode：26.6（17F113）。
- 最低部署目标：macOS 13.0。

## 已通过

- `swift test`：28 项测试通过，0 失败。
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
| Disk I/O counters | 0.04 ms | 8 ms | PASS |
| Volume capacity（低频） | 0.02 ms | 20 ms | PASS |

采样协调器并发执行四类采集；面板关闭时不物化图表数组，也不向 SwiftUI 发布完整快照。

## 常驻 CPU 尖峰优化

2026-08-30 真机诊断确认，磁盘容量读取使用
`volumeAvailableCapacityForImportantUsageKey` 时，macOS 26 会进入 `CacheDelete` 的
可清理空间查询，产生持续数秒的额外队列工作。容量读取现已改为直接调用公开
`statfs`，不再请求 Foundation 的容量资源键：

- Volume capacity 500 次基准由 P95 `6.28 ms` 降至 `0.02 ms`；
- 菜单栏摘要与监控面板改用独立发布状态，避免一次采样使顶层 App、设置页和图表共同失效；
- 默认自适应、面板关闭的 Release 真机 60 个 1 秒样本：平均 CPU `0.280%`，峰值 `0.7%`；
- 同一测试窗口覆盖六次 10 秒容量刷新，未再观察到 `CacheDelete` 调用或两位数 CPU 尖峰；
- 发布门禁禁止重新引入 URL 容量资源键。

## 趋势图内存优化

真机复测发现 Swift Charts 场景会将 physical footprint 从约 17 MB 提升至 134–140 MB，超过 60 MB 产品预算。当前实现改为：

- 移除 `Charts.framework` 动态依赖，使用 SwiftUI `Shape` / `Path` 直接绘制；
- 每条趋势绘制前压缩到最多 60 点；
- 按有序样本桶保留局部最小值与最大值，避免丢失瞬时峰谷；
- 双序列图共享 sequence 范围，避免缺失点导致时间轴错位；
- 图表仍保留坐标、填充、双序列图例和完整可访问性摘要。

面板保持可见并持续绘制 120 秒：

- physical footprint：首个样本 34,657 KB，末样本 35,665 KB，峰值 35,665 KB；
- 外部 socket：0；
- CPU、内存、磁盘、网络单/双序列趋势图均通过真实 UI 与可访问性检查。

## 五分钟稳态门禁

Release-AppStore 构建，30 秒图形预热后测量 300 秒，10 秒采样间隔：

- 30 个样本；
- physical footprint：首个样本 33,425 KB，末样本 33,793 KB，峰值 33,873 KB，增长 368 KB；
- 观察到的 CPU 峰值：6.7%；
- 外部 socket：0；
- 崩溃：0。

长稳脚本先执行 30 秒预热，再计算稳态增长；预热阶段仍持续检查进程存活与外部 socket。该结果通过 60 MB 峰值与 10 MB 稳态增长门禁，但不代表 AC-10 的 8 小时结论。

## 尚需发布阶段执行

- 8 小时与 24 小时长稳、Energy Log、Idle Wake Ups、Leaks / Allocations。
- Intel 实机，以及 macOS 13、14、15 和当前稳定版的完整矩阵。
- Wi‑Fi、Ethernet、VPN、外接卷与真实睡眠/唤醒矩阵。
- Apple 发行证书、Team、Provisioning Profile、Organizer Archive、Privacy Report、公证、TestFlight 与 App Store 审核。
- 公开支持 URL、隐私政策 URL、最终商店截图和版权主体。

这些项目依赖额外硬件、时间或 Apple 开发者资质，不能由单机短时自动化替代；执行命令与验收项见 `doc/RELEASE_CHECKLIST.md`。
