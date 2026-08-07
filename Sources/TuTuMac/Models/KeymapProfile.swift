import Foundation

/// 单个按键映射会触发的动作,坐标使用 0...1 的归一化屏幕比例。
enum KeymapAction: Codable, Hashable {
    case tap(x: Double, y: Double)
    case swipe(x1: Double, y1: Double, x2: Double, y2: Double, durationMS: Int)
    case androidKeyEvent(code: Int)
}

struct KeyBinding: Codable, Hashable, Identifiable {
    var id: UUID = UUID()
    var keyCode: UInt16 // NSEvent.keyCode
    var label: String
    var action: KeymapAction
}

struct KeymapProfile: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var name: String
    var bindings: [KeyBinding]
}
