# PulseBar

PulseBar 是一款原生、轻量的 macOS 菜单栏系统监控工具。它使用一个紧凑的菜单栏项目展示 CPU、内存、磁盘和网络状态；点击后可查看指标拆分、最近趋势与数据口径。

当前正式基线为 **v1.0.0（Build 1）**，最低支持 **macOS 13**。

## 核心能力

- CPU：总占用、用户/系统占用、逻辑核心数、负载平均值和最近趋势。
- 内存：占用、可用、活跃、非活跃、联动、压缩、可清除、交换空间、压力状态和最近趋势。
- 磁盘：本地卷容量、整机读写速率和最近趋势；I/O 不可用时独立降级。
- 网络：主接口状态、上下行速率、会话累计流量和最近趋势。
- 菜单栏：简洁、标准、完整三档密度，支持模块显隐与拖拽排序。
- 运行控制：自适应刷新、暂停/继续、登录时启动、活动监视器快捷入口和恢复入口。
- 辅助功能：简体中文、英文、VoiceOver、浅色/深色和高对比度界面。

## 隐私与资源边界

- App Sandbox，无管理员权限、特权 Helper、完全磁盘访问或辅助功能权限。
- 只使用公开 Mach、BSD、Foundation、IOKit、Network、SystemConfiguration 和 ServiceManagement API。
- 不创建账户，不包含广告、分析、遥测或第三方运行时依赖，不建立外部网络连接。
- 指标只在本机内存中处理；历史数据使用固定容量环形缓冲区，退出应用即清除。
- 趋势图使用 SwiftUI `Shape` / `Path` 绘制，绘制前压缩到最多 60 点并保留局部峰谷。
- 面板隐藏时释放完整快照和图表历史的展示状态，避免图形界面产生持续性内存占用。

详见[隐私政策](doc/PRIVACY.md)和[技术架构](doc/TS/PulseBar_Technical_Architecture_v1.0.md)。

## 开发环境

- Xcode 26 或兼容的 Swift 6 工具链。
- macOS 13 SDK 或更高版本。
- 构建不依赖第三方包或联网下载。

## 构建与测试

```bash
swift test
xcodebuild -project PulseBar.xcodeproj -scheme PulseBar -configuration Debug build
Scripts/verify-release.sh
```

`Scripts/verify-release.sh` 是本地正式发布门禁，覆盖单元测试、本地化与隐私资源、性能基准、Debug/Release 构建、签名与沙盒、运行时依赖、离线边界、系统 API 探针和仓库卫生。

## 本地 Release 包

```bash
Scripts/package-local-release.sh             # 输出到 dist/
Scripts/package-local-release.sh --launch    # 打包后启动新版应用
Scripts/package-local-release.sh --verify    # 打包前执行完整发布门禁
```

脚本生成 `arm64 + x86_64` Universal、ad-hoc 签名的 `.app` 和 ZIP，校验签名、沙盒、资源、架构、依赖及解压产物。产物名称包含版本号和 Git 提交号；工作区存在未提交改动时附加 `-dirty`。

本地产物用于开发验证，不等同于 Apple 发行签名、公证、TestFlight 或 App Store 审核。

## 性能与长稳验证

```bash
Scripts/benchmark-metrics.sh 120
Scripts/soak-test.sh 28800 30   # 8 小时，30 秒采样
Scripts/soak-test.sh 86400 60   # 24 小时，60 秒采样
```

长稳脚本必须显式提供时长和采样间隔，避免误启动长时间任务。当前验证证据和仍需执行的发行矩阵见[质量与验证报告](doc/QUALITY_REPORT.md)及[发布清单](doc/RELEASE_CHECKLIST.md)。

## 项目结构

- `PulseBar/App`：应用生命周期、全局状态和菜单栏入口。
- `PulseBar/Monitoring`：采集器、采样协调器、快照、历史与趋势压缩。
- `PulseBar/Platform`：公开系统 API 适配层。
- `PulseBar/Features`：监控面板、菜单栏、设置、首次启动与恢复界面。
- `PulseBar/Resources`：图标、本地化和隐私清单。
- `PulseBarTests`：采集、调度、历史、格式化和设置单元测试。
- `Tools` / `Scripts`：API 探针、性能、沙盒、长稳、打包与发布验证。

## 正式文档

- [产品需求文档（PRD）](doc/PRD/PulseBar_PRD_v1.0.md)
- [技术架构文档（TS）](doc/TS/PulseBar_Technical_Architecture_v1.0.md)
- [实施基线与里程碑](doc/IMPLEMENTATION_PLAN.md)
- [系统指标 API 可用性报告](doc/TS/Milestone_0_API_Availability_Report.md)
- [质量与验证报告](doc/QUALITY_REPORT.md)
- [发布清单](doc/RELEASE_CHECKLIST.md)
- [App Store 元数据](doc/APP_STORE_METADATA.md)
- [隐私政策](doc/PRIVACY.md)
- [支持与已知限制](doc/SUPPORT.md)

## 支持与反馈

请通过 [GitHub Issues](https://github.com/xiaolin0429/PulseBar/issues) 提交问题或建议，并先阅读[支持与已知限制](doc/SUPPORT.md)。请勿在公开 Issue 中提交令牌、密码、会话信息或其他敏感数据。

v1.1 规划中的告警、通知、长期历史和导出不属于 v1.0 正式范围。
