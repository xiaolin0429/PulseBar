# PulseBar v1.0 实施基线与里程碑记录

更新日期：2026-08-31
状态：v1.0 工程实现完成，发行资质与多设备验收待执行

## 交付目标

依据[产品需求文档](PRD/PulseBar_PRD_v1.0.md)和[技术架构文档](TS/PulseBar_Technical_Architecture_v1.0.md)，交付 macOS 13+ 原生菜单栏监控应用。v1.0 聚焦 CPU、内存、磁盘和网络；所有采集均使用公开系统 API，在本机内存中处理，不请求管理员权限，不建立外部网络连接，不引入第三方运行时依赖。

## v1.0 已实现范围

- 单一组合 `MenuBarExtra`，支持简洁、标准、完整三档密度及模块显隐、拖拽排序。
- CPU 总占用、用户/系统占用、逻辑核心数、负载平均值和历史趋势。
- 内存总量、占用/可用、活跃/非活跃、联动、压缩、可清除、交换空间、压力状态和历史趋势。
- 本地卷容量、整机磁盘读写速率和历史趋势；I/O 不可用时独立降级。
- 主网络接口状态、上下行速率、会话累计量和历史趋势；接口切换时重建基线。
- 监控面板、暂停/继续、活动监视器入口、设置、欢迎页、恢复入口和登录时启动。
- 自适应 1 秒/2 秒刷新、手动 1/2/5 秒刷新、60/120/300 秒固定容量历史、睡眠/唤醒处理。
- 简体中文、英文、VoiceOver、浅色/深色/高对比度、App Sandbox 和隐私清单。
- 轻量 `Shape` / `Path` 图形、最多 60 个绘制点，以及面板隐藏后的展示资源释放。

## 非 v1.0 范围

下列能力属于 v1.1 或后续版本，不得作为 v1.0 已交付能力对外宣传：

- 阈值告警、本地通知和免打扰策略；
- 手动指定接口或同时展示全部网络接口；
- JSON/CSV 导出和跨启动长期历史；
- 电池、GPU、温度、风扇、进程排行或进程管理。

## 里程碑与 Git 节点

每个工程里程碑均在对应构建和测试通过后保存独立 Git 提交。由于公开仓库建立时统一了提交身份，下表以提交主题作为稳定的里程碑标识；确切提交号以 `git log --oneline --reverse` 为准。

| 里程碑 | 提交主题 | 状态 | 主要产物 |
|---|---|---|---|
| 基线 | `chore: establish project baseline` | 完成 | 文档、范围和仓库基础 |
| M0 | `feat: complete milestone 0 system metrics spike` | 完成 | API 探针、核心算法、可用性报告 |
| M1 | `feat: complete milestone 1 app skeleton` | 完成 | Xcode 工程、菜单栏骨架、设置场景、日志 |
| M2 | `feat: complete milestone 2 metric collectors` | 完成 | 四类采集器、并发调度、历史和单元测试 |
| M3 | `feat: complete milestone 3 monitoring dashboard` | 完成 | 四类卡片、趋势图、口径、暂停与快捷操作 |
| M4 | `feat: complete milestone 4 settings and integration` | 完成 | 设置持久化、密度、排序、登录项和本地化 |
| M5 | `chore: complete milestone 5 release readiness` | 工程完成 | 可访问性、隐私、Release/Sandbox 验证和发布资料 |

里程碑之后的体验、性能和缺陷修复均保留为独立提交，包括菜单栏紧凑布局、设置窗口生命周期、拖拽排序、CPU 峰值治理及图形内存优化。

## 完成判定

- 工程完成：PRD 的 v1.0 验收标准、TS 的 Definition of Done 和本地发布门禁均通过。
- 发行完成：还须完成 Apple 发行签名、归档、隐私报告、公证或 App Store 验证、TestFlight 冒烟，以及受支持系统与硬件矩阵。
- 依赖额外设备或时间的项目（Intel、macOS 13/14/15、8/24 小时长稳等）必须保留真实执行证据，不以单机短时自动化结果替代。

当前证据见[质量与验证报告](QUALITY_REPORT.md)，发行操作见[发布清单](RELEASE_CHECKLIST.md)。
