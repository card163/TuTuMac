import Foundation

/// 一个 Android 虚拟设备(AVD)在磁盘上的真实状态,是"模拟器实例"的底层载体。
struct AndroidVirtualDevice: Identifiable, Hashable {
    var id: String { name } // AVD 名称在系统中唯一
    var name: String
    var avdDirectory: URL
    var iniFile: URL
    var deviceProfile: String
    var apiLevel: String
    var abi: String
    var isPlayStoreEnabled: Bool
    var ramSizeMB: Int
    var cpuCoreCount: Int
    var lcdWidth: Int
    var lcdHeight: Int
    var lcdDensity: Int
    var gpuMode: String
    /// 对应 config.ini 的 hw.keyboard;为 no 时电脑物理键盘无法直接向系统输入文字,只会弹软键盘。
    var hostKeyboardEnabled: Bool
}
