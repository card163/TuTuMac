import Foundation

/// 模拟器实例的运行时状态(不持久化)。
enum InstanceStatus: Equatable {
    case stopped
    case starting
    case running(serial: String)
    case stopping
}

/// 一个"模拟器实例" = 一个 AVD + 应用层的元数据(显示名、绑定的按键映射方案等)。
struct EmulatorInstance: Identifiable, Codable, Hashable {
    var id: UUID
    var displayName: String
    var avdName: String
    var keymapProfileID: UUID?
    var createdAt: Date
    var lastLaunchedAt: Date?

    init(
        id: UUID = UUID(),
        displayName: String,
        avdName: String,
        keymapProfileID: UUID? = nil,
        createdAt: Date = Date(),
        lastLaunchedAt: Date? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.avdName = avdName
        self.keymapProfileID = keymapProfileID
        self.createdAt = createdAt
        self.lastLaunchedAt = lastLaunchedAt
    }
}
