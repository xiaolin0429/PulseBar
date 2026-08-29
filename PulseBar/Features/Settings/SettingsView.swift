import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        TabView {
            Form {
                Picker("菜单栏密度", selection: $model.menuBarPreferences.preset) {
                    Text("简洁").tag(MenuBarPreset.compact)
                    Text("标准").tag(MenuBarPreset.standard)
                    Text("完整").tag(MenuBarPreset.complete)
                }
                Text("当前为应用骨架。完整设置将在系统集成里程碑启用。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(20)
            .tabItem { Label("通用", systemImage: "gear") }

            Form {
                Text("所有数据仅在本机内存中处理。")
                Text("不请求管理员、完全磁盘访问或辅助功能权限。")
            }
            .padding(20)
            .tabItem { Label("隐私", systemImage: "hand.raised") }
        }
        .frame(width: 520, height: 300)
    }
}
