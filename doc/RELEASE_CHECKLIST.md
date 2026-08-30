# PulseBar v1.0 发布清单

本清单区分“代码与单机自动化完成”和“需要发布资质或多设备人工验证”。未执行项不得标记为通过。

## 自动化门禁

```bash
Scripts/verify-release.sh
```

门禁覆盖：单元测试、String Catalog、隐私清单、采集 P95 基准、Debug/Release-AppStore、签名与沙盒、运行时依赖、离线源码边界、沙盒原始 API Probe 和仓库卫生。

门禁通过后，可快速生成本地 Universal Release 包：

```bash
Scripts/package-local-release.sh --verify
```

只需快速构建和校验本地产物时，可省略 `--verify`；使用 `--launch` 会在打包后重启 `dist/PulseBar.app`。

## 长稳与能耗

- [ ] 8 小时默认自适应模式：`Scripts/soak-test.sh 28800 30`
- [ ] 24 小时默认自适应模式：`Scripts/soak-test.sh 86400 60`
- [ ] 面板关闭/打开分别记录 CPU、RSS、Energy Impact 和 Idle Wake Ups。
- [ ] 1 秒、2 秒、5 秒策略分别用 Instruments Energy Log 验证。
- [ ] 接电与电池环境各执行一次关键能耗场景。
- [ ] Xcode Leaks / Allocations 检查 Mach、IOKit、getifaddrs 资源生命周期。

短时 soak 只用于验证脚本和发现明显回归，不能替代 8/24 小时结论。

## 系统与硬件矩阵

- [ ] Apple Silicon：macOS 13。
- [ ] Apple Silicon：macOS 14。
- [ ] Apple Silicon：macOS 15。
- [ ] Apple Silicon：当前稳定版。
- [ ] Intel x86_64：至少一个受支持 macOS 版本。
- [ ] Wi‑Fi、Ethernet、VPN、离线与接口切换。
- [ ] APFS 系统卷、外接本地卷、挂载/卸载。
- [ ] 睡眠/唤醒后 5 秒内恢复且无速率尖峰。

## 产品与可访问性

- [ ] 首启、菜单栏恢复、登录项、暂停/继续与打开活动监视器。
- [ ] 简洁/标准/完整密度以及模块显隐、排序、小数位。
- [ ] 简体中文与英文逐页检查，无截断和未翻译字符串。
- [ ] VoiceOver 完整朗读菜单栏摘要、按钮、图表和状态。
- [ ] 键盘导航、增加对比度、减少动态效果、浅色与深色模式。
- [ ] 低磁盘、内存压力、采集失败、预热与过期状态。

## 隐私与商店提交

- [ ] Xcode Organizer 归档并生成 Privacy Report，和 `PrivacyInfo.xcprivacy`、Data Not Collected 标签一致。
- [ ] 最终二进制无外部网络连接、无意外 SDK、无私有 Framework。
- [ ] Developer ID / Mac App Store 证书、Team 与 Provisioning Profile 已配置。
- [ ] 公证或 App Store 验证通过；TestFlight for Mac 冒烟通过。
- [ ] 支持 URL 与公开隐私政策 URL 已填写。
- [ ] 截图、描述、关键词、年龄分级和版权主体已确认。

本地 ad-hoc 签名只能证明签名结构、沙盒 entitlement 与运行行为，不能替代 Apple 发行签名、公证、TestFlight 或 App Store 审核。
