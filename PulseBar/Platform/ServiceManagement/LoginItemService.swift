import ServiceManagement

enum LoginItemStatus: Equatable {
    case enabled
    case requiresApproval
    case disabled
    case notFound
}
protocol LoginItemServicing {
    var status: LoginItemStatus { get }
    /// 请求开启或关闭登录项；注册失败通过 throws 交由界面呈现。
    func setEnabled(_ enabled: Bool) throws
    /// 打开系统登录项设置页，让用户完成需要的批准操作。
    func openSystemSettings()
}

struct LoginItemService: LoginItemServicing {
    var status: LoginItemStatus {
        switch SMAppService.mainApp.status {
        case .enabled: .enabled
        case .requiresApproval: .requiresApproval
        case .notRegistered: .disabled
        case .notFound: .notFound
        @unknown default: .disabled
        }
    }

    /// 调用系统主应用注册或注销 API；是否需要用户批准由调用方回读 status 判断。
    func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }

    /// 跳转到 macOS 登录项设置页，不自行修改系统批准状态。
    func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
