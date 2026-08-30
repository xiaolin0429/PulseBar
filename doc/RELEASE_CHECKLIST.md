# PulseBar v1.0 发布清单

更新日期：2026-08-31
适用版本：1.0.0（Build 1）

本清单区分本地已验证项目与仍需真实发行环境执行的项目：

- `[x]`：已有可复现证据；
- `[ ]`：尚未执行或仍需最终归档复核；
- 未执行项不得仅因构建成功而标记为通过。

## 1. 本地自动化门禁

标准入口：

```bash
Scripts/verify-release.sh
```

已验证：

- [x] 38 项 Swift 单元测试通过。
- [x] String Catalog 和隐私清单存在并打入应用。
- [x] 原始采集器 P95 性能预算通过。
- [x] Debug 与 Release-AppStore arm64 构建通过。
- [x] Release-AppStore x86_64 交叉编译通过。
- [x] ad-hoc Hardened Runtime 签名和 App Sandbox entitlement 检查通过。
- [x] 运行时依赖、离线源码边界和短时外部 socket 检查通过。
- [x] 沙盒系统指标 Probe 通过。
- [x] 仓库卫生检查通过；打包产物不进入版本控制。

## 2. 本地 Universal 包

完整门禁后打包：

```bash
Scripts/package-local-release.sh --verify
```

快速重建可省略 `--verify`；加入 `--launch` 可在打包后重启 `dist/PulseBar.app`。

- [x] 脚本生成 `arm64 + x86_64` Universal `.app` 和 ZIP。
- [x] 脚本校验架构、签名、沙盒、资源、依赖和 ZIP 解压产物。
- [ ] 最终候选包必须在干净工作区、目标版本标签和最终文档提交上重新生成。
- [ ] 不得将本地 ad-hoc 包误标为已公证或 App Store 正式包。

## 3. 功能与体验

本机基线已验证：

- [x] 菜单栏三档密度、模块显隐和顺序持久化。
- [x] 右侧句柄拖拽整行，且移动限制在垂直列表内。
- [x] 模块开关对齐，至少保留一个模块，磁盘仅在完整密度显示。
- [x] 设置窗口首次创建、被覆盖后前置、关闭后重建。
- [x] 数据口径展开/闭合时卡片与趋势图同步布局。
- [x] 暂停/继续、活动监视器入口、首次启动和恢复入口。
- [x] 简体中文、英文及主要可访问性树检查。

最终候选包仍须复核：

- [ ] 所有页面无截断、遮挡、错位、错误动画或菜单栏溢出。
- [ ] VoiceOver 完整朗读摘要、按钮、图表和状态。
- [ ] 键盘导航、增加对比度、减少动态效果、浅色和深色模式。
- [ ] 低磁盘、内存压力、采集失败、预热和过期状态。
- [ ] 产品负责人完成最终发行验收。

## 4. 内存、CPU 与长稳

- [x] 图形可见 120 秒峰值低于 60 MB，末值 35,665 KB。
- [x] 五分钟稳态峰值 33,873 KB，增长 368 KB，无崩溃和外部 socket。
- [x] 面板关闭时 60 秒 CPU 平均 0.280%，峰值 0.7%。
- [x] 隐藏面板会清除完整快照/历史展示状态并卸载完整卡片树。
- [ ] 真机解锁状态复测首次打开、关闭并稳定后的 physical footprint 回落。
- [ ] 8 小时默认自适应：`Scripts/soak-test.sh 28800 30`。
- [ ] 24 小时默认自适应：`Scripts/soak-test.sh 86400 60`。
- [ ] 面板关闭和打开分别记录 CPU、physical footprint、Energy Impact 与 Idle Wake Ups。
- [ ] 1 秒、2 秒、5 秒策略分别使用 Instruments Energy Log 验证。
- [ ] 接电和电池环境各执行一次关键能耗场景。
- [ ] Xcode Leaks / Allocations 检查 Mach、IOKit、`getifaddrs` 和图形资源生命周期。

短时 soak 只用于验证脚本和发现明显回归，不能替代 8/24 小时结论。

## 5. 系统与硬件矩阵

- [ ] Apple Silicon：macOS 13。
- [ ] Apple Silicon：macOS 14。
- [ ] Apple Silicon：macOS 15。
- [ ] Apple Silicon：当前稳定版。
- [ ] Intel x86_64：至少一个受支持 macOS 版本。
- [ ] Wi‑Fi、Ethernet、VPN、离线和接口切换。
- [ ] APFS 系统卷、外接本地卷和挂载/卸载。
- [ ] 睡眠/唤醒后五秒内恢复且不产生速率尖峰。

## 6. Apple 发行与商店提交

- [ ] Apple Developer Team、Bundle ID、证书和 Provisioning Profile 已配置。
- [ ] Xcode Organizer 使用最终版本和干净提交完成 Archive。
- [ ] Organizer Privacy Report 与 `PrivacyInfo.xcprivacy`、[隐私政策](PRIVACY.md)和 “Data Not Collected” 一致。
- [ ] 最终二进制无外部网络连接、意外 SDK 或私有 Framework。
- [ ] Developer ID 发行完成公证与 Gatekeeper 验证，或 Mac App Store 验证通过。
- [ ] TestFlight for Mac 安装、启动、设置和核心指标冒烟通过。
- [ ] [App Store 元数据](APP_STORE_METADATA.md)中的截图、描述、关键词、年龄分级、版权和 URL 已确认。
- [ ] 发布版本号、Build 号、Git 标签和归档记录一致。
- [ ] 产品负责人批准发行。

本地 ad-hoc 签名只证明签名结构、沙盒 entitlement 和当前运行行为，不能替代 Apple 发行签名、公证、TestFlight 或 App Store 审核。
