import Foundation

/// 性能相关设置,对应 AVD config.ini 中的一部分字段。
struct PerformanceProfile: Codable, Equatable {
    var ramSizeMB: Int
    var cpuCoreCount: Int
    var lcdWidth: Int
    var lcdHeight: Int
    var lcdDensity: Int
    var gpuMode: String // "host" | "swiftshader_indirect" | "auto"
    /// true 时写入 hw.keyboard=yes,让电脑物理键盘可以直接输入到虚拟机。
    var hostKeyboardEnabled: Bool

    static let `default` = PerformanceProfile(
        ramSizeMB: 2048, cpuCoreCount: 4,
        lcdWidth: 1080, lcdHeight: 1920, lcdDensity: 420,
        gpuMode: "host", hostKeyboardEnabled: true
    )
}
