# Milestone 0：系统指标 API 可用性报告

验证日期：2026-08-29

## 验证环境

- 架构：arm64
- 系统：macOS 26.6.2（Build 25G83）
- 工具链：Apple Swift 6.3.3、Xcode 26.6
- 运行形态：Release 编译；临时 `.app` Bundle；ad-hoc 签名；App Sandbox 开启；无网络 entitlement

## 结果

| 能力 | API | 结果 | 本机观察 |
|---|---|---|---|
| CPU Tick | `host_processor_info` | PASS | 返回 18 个逻辑处理器；单次读取约 0.03 ms |
| VM 统计 | `host_statistics64` / `host_page_size` | PASS | 页大小 16 KiB；单次读取约 0.01 ms |
| Swap | `sysctlbyname(vm.swapusage)` | PASS | 返回总量、占用和可用；单次读取约 0.01 ms |
| 网络计数 | `getifaddrs` | PASS | 返回 24 个接口；主接口由 SystemConfiguration 解析为 `en0`；约 0.34 ms |
| 卷容量 | Foundation URL Resource Values | PASS | 返回 1 个本地卷；完整枚举约 18 ms |
| 磁盘 I/O | IOKit `IOBlockStorageDriver` Statistics | PASS | 返回 4 个块存储计数器；约 0.08 ms |
| 相邻样本 | 1 秒单调时钟窗口 | PASS | CPU、磁盘与网络差值均可计算，无负数、NaN 或溢出 |

采样耗时是一次本机观察，不代表所有设备上的性能承诺。卷枚举明显高于其他读取，应按架构要求在事件触发或低频路径执行，不能每秒完整枚举。

## 沙盒验证

`Scripts/verify-sandbox-probe.sh` 会构建 Release 探针，放入临时应用 Bundle，附加 `com.apple.security.app-sandbox = true` entitlement，验证签名后执行。四类系统指标在该环境下均可读取，且没有开启 Incoming/Outgoing Network entitlement。

裸 Mach-O 命令行文件直接附加 App Sandbox entitlement 会因缺少应用 Bundle 上下文被系统拒绝启动，因此正式验证必须使用 `.app` Bundle；该现象不代表指标 API 不可用。

## 尚需设备矩阵验证

- x86_64 Intel Mac；
- macOS 13、14、15；
- Wi-Fi / Ethernet / VPN 主接口切换；
- 外接 SSD、U 盘、磁盘映像和网络卷；
- 睡眠/唤醒后的基线重建；
- 8/24 小时稳定性、泄漏与能耗。

上述项目需要后续正式 App、对应硬件或长时间窗口，不能由本机短时探针结果替代。
