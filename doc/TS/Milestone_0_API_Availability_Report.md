# PulseBar v1.0 系统指标 API 可用性报告

首次验证：2026-08-29
更新日期：2026-08-31
状态：Milestone 0 完成，API 已进入 v1.0 正式实现

## 1. 目标

在 App Sandbox、无网络 entitlement、无管理员权限和无特权 Helper 的条件下，验证 CPU、内存、卷容量、磁盘 I/O 与网络指标所需的公开 macOS API，并建立性能与降级基线。

## 2. 验证环境

- 架构：Apple Silicon `arm64`。
- 系统：macOS 26.6.2（Build 25G83）。
- 工具链：Apple Swift 6.3.3、Xcode 26.6。
- 运行形态：Release 编译、临时 `.app` Bundle、ad-hoc 签名、App Sandbox 开启、无网络 entitlement。

## 3. API 结论

| 能力 | 正式实现 API | 结果 | 关键结论 |
|---|---|---|---|
| CPU tick | `host_processor_info` | PASS | 返回逻辑处理器 tick；相邻样本计算总量及用户/系统占用 |
| VM 统计 | `host_statistics64` / `host_page_size` | PASS | 页计数可换算内存拆分与占用 |
| Swap | `sysctlbyname(vm.swapusage)` | PASS | 返回总量、占用和可用量 |
| 内存压力 | `DispatchSourceMemoryPressure` | PASS | 以系统压力事件补充内存状态 |
| 网络计数 | `getifaddrs` | PASS | 读取接口累计字节；主接口由 SystemConfiguration 解析 |
| 卷枚举 | `FileManager.mountedVolumeURLs` 与 URL 元数据 | PASS | 只保留本地卷并读取名称、标识及设备属性 |
| 卷容量 | Darwin `statfs` | PASS | 使用总块数与普通可用块数，不触发可清理空间扫描 |
| 磁盘 I/O | IOKit `IOBlockStorageDriver` Statistics | PASS | 累计读写字节可用于相邻样本速率 |
| 相邻样本 | 单调时钟差值 | PASS | CPU、磁盘和网络差值可计算；重置或回绕时重建基线 |

## 4. 当前性能基线

Release 原始采集器 120 次门禁结果：

| 采集项 | P95 | 预算 |
|---|---:|---:|
| CPU raw | 0.01 ms | 3 ms |
| Memory raw | 0.00 ms | 3 ms |
| Network counters | 0.01 ms | 3 ms |
| Disk I/O counters | 0.04 ms | 8 ms |
| Volume capacity（低频） | 0.02 ms | 20 ms |

数值是当前设备上的可复现观察，不构成所有设备的绝对性能承诺。卷列表与容量位于低频路径，不随每秒快照重复枚举。

## 5. 关键实现决策

### 5.1 普通可用容量

早期验证使用 Foundation 的“重要用途可用容量”资源键，macOS 26 会触发 `CacheDelete` 的可清理空间计算，带来明显 CPU 峰值。正式实现改用公开 `statfs`：

- 总容量：`f_blocks * f_bsize`；
- 普通可用容量：`f_bavail * f_bsize`；
- 计算使用溢出安全的整数路径；
- 文案明确该值可能与 Finder 的可清理空间口径不同。

发布门禁禁止重新引入相关 URL 容量资源键。

### 5.2 差值型指标

CPU tick、磁盘 I/O 和网络字节都是累计计数。正式实现遵循：

- 第一个样本仅建立基线；
- 使用单调时钟计算时间窗；
- 接口切换、睡眠/唤醒、计数器回绕或间隔异常时重建基线；
- 预热期间显示不可用状态，不制造零值或尖峰；
- 所有百分比和速率输出拒绝 NaN、无穷大及负值。

### 5.3 独立降级

单个 API 失败不阻断其他模块：

- 磁盘 I/O 不可用时，卷容量继续显示；
- 主网络接口未解析时，显示离线或预热，不累计错误会话流量；
- 内存压力事件不可用时，基础 VM 数据继续显示；
- 错误细节写入本地统一日志，不上传。

## 6. 沙盒验证方式

`Scripts/verify-sandbox-probe.sh` 构建 Release 探针，将其放入临时 `.app` Bundle，附加 `com.apple.security.app-sandbox = true` entitlement，验证签名后执行。正式指标在该环境中均可读取，且未启用 Incoming/Outgoing Network entitlement。

裸 Mach-O 命令行文件直接附加 App Sandbox entitlement 可能因缺少应用 Bundle 上下文被系统拒绝启动，因此沙盒结论必须来自 `.app` Bundle 探针。

## 7. 仍需覆盖的发行矩阵

- Intel x86_64 实机；
- macOS 13、14、15 和当前稳定版；
- Wi‑Fi、Ethernet、VPN、离线及主接口切换；
- 外接 SSD、U 盘、本地卷挂载和卸载；
- 真实睡眠/唤醒后的基线重建；
- 8/24 小时稳定性、泄漏和能耗。

这些项目依赖对应硬件或长时间窗口，不由单机短时探针替代。执行状态以[发布清单](../RELEASE_CHECKLIST.md)为准。
