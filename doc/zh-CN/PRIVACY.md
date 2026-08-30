[English](../en/PRIVACY.md) | 简体中文

# PulseBar 隐私政策

生效及更新日期：2026-08-31
适用版本：PulseBar 1.0.x

PulseBar 完全在用户的 Mac 上运行，不收集、上传、出售或共享个人数据。

## 本机处理的数据

PulseBar 读取 CPU、内存、磁盘容量与 I/O、网络接口状态和吞吐等系统指标，以便在菜单栏及监控面板中显示。指标只在应用进程的内存中处理；最近趋势使用固定容量内存缓冲区，应用退出后即清除。

用户选择的显示、刷新、语言和启动设置通过 macOS `UserDefaults` 保存在 PulseBar 自己的沙盒容器中。PulseBar 不读取其他应用的偏好设置。

## PulseBar 不会执行的行为

- 不创建或要求账户；
- 不包含广告、分析、遥测或崩溃上报 SDK；
- 不建立外部网络连接；
- 不请求管理员、完全磁盘访问或辅助功能权限；
- 不读取文件内容、浏览历史、联系人、位置或其他个人内容；
- 不将系统指标写入长期历史文件或云端。

## 分发与项目网站

项目源码和文档托管于 GitHub。用户主动访问项目网站或 GitHub Issues 时，相关网站的数据处理由其服务提供方及用户自身设置决定；这不属于 PulseBar 应用的运行时数据收集。

Mac App Store 隐私标签应申报为 “Data Not Collected（不收集数据）”。最终申报必须与实际提交二进制生成的 Privacy Report 一致。

隐私问题可通过 [GitHub Issues](https://github.com/xiaolin0429/PulseBar/issues) 联系项目维护者。公开反馈中请勿包含密码、令牌、会话信息或其他敏感数据。
