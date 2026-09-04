import Foundation
import SystemConfiguration

public struct SystemPrimaryInterfaceResolver: PrimaryInterfaceResolving {
    /// 创建无状态的主接口解析器。
    public init() {}

    /// 先查询 IPv4、再查询 IPv6 的全局主接口；均无有效名称时返回 nil。
    public func primaryInterfaceName() -> String? {
        let keys = ["State:/Network/Global/IPv4", "State:/Network/Global/IPv6"]
        for key in keys {
            guard let value = SCDynamicStoreCopyValue(nil, key as CFString) as? [String: Any] else {
                continue
            }
            if let name = value["PrimaryInterface"] as? String, !name.isEmpty {
                return name
            }
        }
        return nil
    }
}
