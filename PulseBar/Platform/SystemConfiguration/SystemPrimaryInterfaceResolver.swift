import Foundation
import SystemConfiguration

public struct SystemPrimaryInterfaceResolver: PrimaryInterfaceResolving {
    public init() {}

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
