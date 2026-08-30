# PulseBar

PulseBar 是一款原生 macOS 菜单栏系统监控工具。它以单一菜单栏项目展示 CPU、内存、磁盘和网络状态，点击后提供最近趋势、指标拆分与口径说明。

## 产品边界

- macOS 13+，SwiftUI + 轻量 `Path` 趋势绘制。
- 使用公开 Mach、BSD、Foundation、IOKit、Network 与 SystemConfiguration API。
- App Sandbox，无管理员权限、无特权 Helper。
- 不建立外部网络连接，不含广告、遥测或第三方运行时依赖。
- 历史数据只保存在固定容量内存缓冲区；绘制前按有序样本桶压缩到最多 60 点并保留峰谷，退出应用即清除。

## 构建与验证

需要 Xcode 26 或兼容的 Swift 6 工具链。

```bash
swift test
xcodebuild -project PulseBar.xcodeproj -scheme PulseBar -configuration Debug build
Scripts/verify-release.sh
```

快速生成本地 Universal Release 包：

```bash
Scripts/package-local-release.sh             # 输出到 dist/
Scripts/package-local-release.sh --launch    # 打包后重启新版应用
Scripts/package-local-release.sh --verify    # 先执行完整发布门禁
```

脚本会生成 `arm64 + x86_64` 的 ad-hoc 签名应用与 ZIP，校验签名、沙盒、资源、依赖及解压产物，并用版本号和 Git 提交号命名。工作区有未提交变更时，文件名会带 `-dirty`。

指标性能基准：

```bash
Scripts/benchmark-metrics.sh 120
```

长稳测试必须显式指定时长，避免误启动长任务：

```bash
Scripts/soak-test.sh 28800 30   # 8 小时
Scripts/soak-test.sh 86400 60   # 24 小时
```

## 项目结构

- `PulseBar/App`：应用生命周期与全局状态。
- `PulseBar/Monitoring`：采集器、采样协调、快照与历史。
- `PulseBar/Platform`：系统 API 适配层。
- `PulseBar/Features`：菜单栏、面板、设置与首次启动界面。
- `PulseBar/Resources`：图标、本地化与隐私清单。
- `PulseBarTests`：采集算法、状态机、历史与设置测试。
- `Tools` / `Scripts`：系统 API、性能、沙盒、长稳和发布验证。

## 文档

- [实现计划](doc/IMPLEMENTATION_PLAN.md)
- [隐私政策](doc/PRIVACY.md)
- [发布清单](doc/RELEASE_CHECKLIST.md)
- [本地质量报告](doc/QUALITY_REPORT.md)
- [App Store 元数据](doc/APP_STORE_METADATA.md)
- [支持与已知限制](doc/SUPPORT.md)
- [PRD](doc/PRD/PulseBar_PRD_v1.0.md)
- [技术方案](doc/TS/PulseBar_Technical_Architecture_v1.0.md)

v1.1 告警、通知、长期历史和导出不在 v1.0 范围内。
