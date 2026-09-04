import AppKit
import SwiftUI

struct SettingsView: View {
    private static let moduleRowStride: CGFloat = 49

    @EnvironmentObject private var model: AppModel
    @State private var confirmReset = false
    @State private var draggedModule: MenuBarModule?
    @GestureState private var moduleDragOffset: CGFloat = 0

    var body: some View {
        TabView {
            generalSettings
                .tabItem { Label("通用", systemImage: "gear") }
            menuBarSettings
                .tabItem { Label("菜单栏", systemImage: "menubar.rectangle") }
            monitoringSettings
                .tabItem { Label("监控", systemImage: "waveform.path.ecg") }
            privacySettings
                .tabItem { Label("隐私与关于", systemImage: "hand.raised") }
        }
        .frame(width: 600, height: 440)
        .background {
            SettingsWindowRegistrationView()
                .frame(width: 0, height: 0)
        }
        .alert("恢复默认设置？", isPresented: $confirmReset) {
            Button("取消", role: .cancel) {}
            Button("恢复默认", role: .destructive) { model.resetSettings() }
        } message: {
            Text("菜单栏、刷新和显示设置将恢复默认；首次启动完成状态不会改变。")
        }
        .alert(
            "系统操作未完成",
            isPresented: Binding(
                get: { model.systemIntegrationError != nil },
                set: { if !$0 { model.systemIntegrationError = nil } }
            )
        ) {
            Button("好", role: .cancel) { model.systemIntegrationError = nil }
        } message: {
            Text(model.systemIntegrationError ?? "")
        }
    }

    private var generalSettings: some View {
        Form {
            Section("启动") {
                Toggle(
                    "登录时自动启动",
                    isOn: Binding(
                        get: { model.settings.launchAtLogin },
                        set: { model.setLaunchAtLogin($0) }
                    )
                )
                loginItemStatus

                Toggle("在 Dock 中显示图标", isOn: $model.settings.showDockIcon)

                Picker("重新打开应用时", selection: $model.settings.openBehavior) {
                    Text("只保持菜单栏").tag(AppOpenBehavior.menuBarOnly)
                    Text("打开监控面板").tag(AppOpenBehavior.showDashboard)
                }
            }

            Section("语言") {
                Picker("界面语言", selection: $model.settings.language) {
                    Text("跟随系统").tag(AppLanguage.system)
                    Text("简体中文").tag(AppLanguage.simplifiedChinese)
                    Text("English").tag(AppLanguage.english)
                }
            }

            Section {
                Button("恢复默认设置…") { confirmReset = true }
            }
        }
        .formStyle(.grouped)
        .padding(12)
    }

    @ViewBuilder
    private var loginItemStatus: some View {
        switch model.loginItemStatus {
        case .enabled:
            Label("登录项已启用", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.caption)
        case .requiresApproval:
            HStack {
                Label("等待系统批准", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Spacer()
                Button("打开系统设置") { model.openLoginItemSettings() }
            }
            .font(.caption)
        case .disabled:
            Text("默认关闭；开启后由 macOS 管理登录项。")
                .font(.caption)
                .foregroundStyle(.secondary)
        case .notFound:
            Text("当前构建无法注册为登录项。请从“应用程序”目录运行签名版本。")
                .font(.caption)
                .foregroundStyle(.orange)
        }
    }

    private var menuBarSettings: some View {
        Form {
            Section("实时预览") {
                HStack {
                    Spacer()
                    MenuBarLabelView(summary: .preview, preferences: model.menuBarPreferences)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(.regularMaterial, in: Capsule())
                    Spacer()
                }
                .padding(.vertical, 6)
            }

            Section("样式") {
                Picker("密度", selection: $model.settings.menuBarPreset) {
                    Text("简洁").tag(MenuBarPreset.compact)
                    Text("标准").tag(MenuBarPreset.standard)
                    Text("完整").tag(MenuBarPreset.complete)
                }
                .pickerStyle(.segmented)
                Toggle("显示一位小数", isOn: $model.settings.showDecimals)
            }

            Section("模块与顺序") {
                ForEach(model.settings.orderedModules) { module in
                    moduleRow(module)
                }
                Text("上下拖动右侧手柄调整顺序。至少保留一个模块；磁盘仅在完整密度中显示。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding(12)
    }

    private func moduleRow(_ module: MenuBarModule) -> some View {
        let isVisible = model.settings.visibleModules.contains(module)
        let orderedModules = model.settings.orderedModules
        let index = orderedModules.firstIndex(of: module)
        return HStack(spacing: 12) {
            Text(moduleLabel(module))
                .frame(maxWidth: .infinity, alignment: .leading)
            Toggle(
                moduleLabel(module),
                isOn: Binding(
                    get: { model.settings.visibleModules.contains(module) },
                    set: { model.toggleModule(module, visible: $0) }
                )
            )
            .labelsHidden()
            .toggleStyle(.switch)
            .frame(width: 42, alignment: .trailing)

            Image(systemName: "line.3.horizontal")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 24, height: 24)
                .contentShape(Rectangle())
                .gesture(moduleReorderGesture(for: module))
                .help("上下拖动调整模块顺序")
                .accessibilityLabel(Text(moduleLabel(module)))
                .accessibilityHint("上下拖动调整模块顺序")
                .accessibilityAdjustableAction { direction in
                    switch direction {
                    case .increment:
                        withAnimation { model.moveModule(module, offset: 1) }
                    case .decrement:
                        withAnimation { model.moveModule(module, offset: -1) }
                    @unknown default:
                        break
                    }
                }
        }
        .padding(.vertical, 2)
        .background {
            if draggedModule == module {
                RoundedRectangle(cornerRadius: 6)
                    .fill(.regularMaterial)
            }
        }
        .overlay {
            if draggedModule == module {
                RoundedRectangle(cornerRadius: 6)
                    .stroke(.separator.opacity(0.7), lineWidth: 1)
            }
        }
        .shadow(
            color: draggedModule == module ? .black.opacity(0.16) : .clear,
            radius: 8,
            y: 3
        )
        .contextMenu {
            Button("上移") {
                withAnimation { model.moveModule(module, offset: -1) }
            }
            .disabled(index == 0)
            Button("下移") {
                withAnimation { model.moveModule(module, offset: 1) }
            }
            .disabled(index == orderedModules.count - 1)
        }
        .opacity(isVisible ? 1 : 0.8)
        .offset(y: draggedModule == module ? constrainedDragOffset(for: module) : 0)
        .zIndex(draggedModule == module ? 1 : 0)
        .animation(.easeInOut(duration: 0.15), value: orderedModules)
        .animation(.easeOut(duration: 0.12), value: draggedModule)
    }

    /// 从右侧句柄启动局部重排，只读取纵向位移；松手后才提交模块新顺序。
    /// 不创建系统自由拖放预览，避免行跟随指针横向飞出列表。
    private func moduleReorderGesture(for module: MenuBarModule) -> some Gesture {
        DragGesture(minimumDistance: 4, coordinateSpace: .global)
            .updating($moduleDragOffset) { value, state, _ in
                state = value.translation.height
            }
            .onChanged { _ in
                if draggedModule != module {
                    draggedModule = module
                }
            }
            .onEnded { value in
                moveModuleAfterDrag(module, verticalTranslation: value.translation.height)
                withAnimation(.easeOut(duration: 0.12)) {
                    draggedModule = nil
                }
            }
    }

    private func constrainedDragOffset(for module: MenuBarModule) -> CGFloat {
        let orderedModules = model.settings.orderedModules
        guard let index = orderedModules.firstIndex(of: module) else { return 0 }
        let minimum = -CGFloat(index) * Self.moduleRowStride
        let maximum = CGFloat(orderedModules.count - index - 1) * Self.moduleRowStride
        return min(max(moduleDragOffset, minimum), maximum)
    }

    /// 将纵向位移除以固定行距并取整，限制目标索引后以动画提交排序。
    private func moveModuleAfterDrag(_ module: MenuBarModule, verticalTranslation: CGFloat) {
        let orderedModules = model.settings.orderedModules
        guard let sourceIndex = orderedModules.firstIndex(of: module) else { return }
        let rowDelta = Int((verticalTranslation / Self.moduleRowStride).rounded())
        let targetIndex = min(max(sourceIndex + rowDelta, 0), orderedModules.count - 1)
        guard targetIndex != sourceIndex else { return }

        withAnimation(.easeInOut(duration: 0.15)) {
            model.moveModule(module, to: orderedModules[targetIndex])
        }
    }

    private var monitoringSettings: some View {
        Form {
            Section("刷新") {
                Picker("刷新策略", selection: $model.settings.refreshPolicy) {
                    Text("自适应（面板 1 秒 / 后台 2 秒）").tag(RefreshPolicy.adaptive)
                    Text("每 1 秒").tag(RefreshPolicy.everySecond)
                    Text("每 2 秒").tag(RefreshPolicy.everyTwoSeconds)
                    Text("每 5 秒").tag(RefreshPolicy.everyFiveSeconds)
                }
                Picker("历史窗口", selection: $model.settings.historyWindow) {
                    Text("60 秒").tag(HistoryWindow.seconds60)
                    Text("2 分钟").tag(HistoryWindow.seconds120)
                    Text("5 分钟").tag(HistoryWindow.seconds300)
                }
            }

            Section("单位") {
                Picker("容量与速率", selection: $model.settings.unitSystem) {
                    Text("默认（容量 IEC / 速率 SI）").tag(UnitSystem.mixedDefault)
                    Text("十进制 SI").tag(UnitSystem.decimal)
                    Text("二进制 IEC").tag(UnitSystem.binary)
                }
            }

            Section("来源") {
                LabeledContent("网络接口") {
                    Text("自动选择系统主接口")
                }
                LabeledContent("磁盘卷") {
                    Text("系统数据卷")
                }
                Toggle("睡眠时暂停", isOn: .constant(true))
                    .disabled(true)
            }
        }
        .formStyle(.grouped)
        .padding(12)
    }

    private var privacySettings: some View {
        Form {
            Section("隐私") {
                Label("无数据收集", systemImage: "checkmark.shield.fill")
                    .foregroundStyle(.green)
                Text("CPU、内存、磁盘和网络指标只在本机内存中处理。PulseBar 不保存历史、不建立外部网络连接，也不包含广告或分析 SDK。")
                    .foregroundStyle(.secondary)
            }

            Section("权限") {
                permissionRow("管理员权限", granted: false)
                permissionRow("完全磁盘访问", granted: false)
                permissionRow("辅助功能", granted: false)
                permissionRow("外部网络连接", granted: false)
            }

            Section("关于") {
                LabeledContent("版本", value: appVersion)
                Text("指标由公开的 Mach、BSD、Foundation、IOKit、Network 与 SystemConfiguration API 提供。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding(12)
    }

    private func permissionRow(_ title: LocalizedStringKey, granted: Bool) -> some View {
        HStack {
            Text(title)
            Spacer()
            if granted {
                Text("已请求")
                    .foregroundStyle(.orange)
            } else {
                Text("未请求")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func moduleLabel(_ module: MenuBarModule) -> LocalizedStringKey {
        switch module {
        case .cpu: "CPU"
        case .memory: "内存"
        case .disk: "磁盘"
        case .network: "网络"
        }
    }

    private var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
            ?? "1.0.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(version) (\(build))"
    }
}

private struct SettingsWindowRegistrationView: NSViewRepresentable {
    func makeNSView(context: Context) -> SettingsWindowRegistrationNSView {
        SettingsWindowRegistrationNSView()
    }

    func updateNSView(_ nsView: SettingsWindowRegistrationNSView, context: Context) {}
}

@MainActor
private final class SettingsWindowRegistrationNSView: NSView {
    /// 视图挂入窗口后登记真实 NSWindow，使设置按钮能复用并置前已有窗口。
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard let window else { return }
        AppDelegate.shared?.registerSettingsWindow(window)
    }
}
