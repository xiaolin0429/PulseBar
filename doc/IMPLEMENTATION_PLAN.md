# PulseBar v1.0 实施计划

## 交付目标

依据 `PulseBar_PRD_v1.0.md` 与 `PulseBar_Technical_Architecture_v1.0.md`，交付 macOS 13+ 原生菜单栏监控应用。v1.0 聚焦 CPU、内存、磁盘与网络，所有采集均使用公开系统 API，在本机内存中处理，不请求管理员权限，不建立外部网络连接，不引入第三方运行时依赖。

## v1.0 范围

- 单一组合 `MenuBarExtra`，默认显示 CPU、内存、网络；支持简洁、标准、完整密度。
- CPU 总占用、用户/系统占用、逐核心、负载平均值与历史趋势。
- 内存总量、占用/可用、活跃/非活跃、联动、压缩、可清除、Swap、压力状态与历史趋势。
- 系统卷及本地卷容量、整机读写速率与历史趋势；I/O 不可用时独立降级。
- 网络在线状态、主接口、上下行速率、会话累计量与历史趋势；接口切换重建基线。
- 弹出面板、暂停/继续、活动监视器快捷入口、设置、欢迎与恢复入口、登录时启动。
- 自适应 1 秒/2 秒刷新、60/120/300 秒固定容量历史、睡眠/唤醒处理。
- 简体中文和英文、VoiceOver、浅色/深色/高对比度、App Sandbox 与隐私清单。

## 非本期范围

PRD v1.1/v2.0 的本地告警、通知、手动/全部网络接口、JSON/CSV 导出、长期历史、电池、GPU、温度、风扇、进程管理不进入 v1.0。

## Git 里程碑

每个里程碑在构建和对应测试通过后创建本地提交：

1. `chore: establish project baseline`：文档与实施边界。
2. `feat: complete milestone 0 system metrics spike`：公开 API 探针、核心算法及可用性报告。
3. `feat: complete milestone 1 app skeleton`：Xcode 工程、菜单栏骨架、设置场景、AppModel 与日志。
4. `feat: complete milestone 2 metric collectors`：四类采集器、统一调度、历史、生命周期及单元测试。
5. `feat: complete milestone 3 monitoring dashboard`：四卡片、图表、口径说明、暂停/继续与快捷操作。
6. `feat: complete milestone 4 settings and integration`：设置持久化、预设/排序、登录启动、欢迎/恢复、中英文。
7. `chore: complete milestone 5 release readiness`：可访问性、隐私、Release/Sandbox 验证、发布文档和自动化验收。

## 完成判定

代码层完成以 TS 的 Definition of Done 和 PRD AC-01 至 AC-10 为准。依赖多设备或长时间运行的项目（Intel、macOS 13/14/15、8/24 小时、签名/TestFlight/App Store）必须保留可复现的人工验收清单，不能以单机短时自动化结果冒充通过。
