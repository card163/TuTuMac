import Foundation
import AppKit
import CoreGraphics

/// 在模拟器窗口前台时,将键盘事件转换为 adb 触控/按键指令。
///
/// 已知限制:emulator 启动器进程有时会另起真正承载 UI 的子进程(qemu),
/// 这里以 `EmulatorProcessManager` 记录的 pid 做最佳努力匹配;
/// 如果按键没有反应,请确认模拟器窗口确实处于最前台且已授权辅助功能权限。
final class KeymapEngine {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    private let adb: ADBService
    private var activeSerial: String?
    private var activeProfile: KeymapProfile?
    private var screenSize: (width: Int, height: Int) = (1080, 1920)
    private var targetProcessIdentifier: pid_t?

    init(adb: ADBService) {
        self.adb = adb
    }

    static var hasAccessibilityPermission: Bool {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: false]
        return AXIsProcessTrustedWithOptions(options)
    }

    static func requestAccessibilityPermission() {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true]
        _ = AXIsProcessTrustedWithOptions(options)
    }

    func activate(profile: KeymapProfile, serial: String, targetPID: pid_t, screenSize: (width: Int, height: Int)) {
        activeProfile = profile
        activeSerial = serial
        targetProcessIdentifier = targetPID
        self.screenSize = screenSize
        guard eventTap == nil else { return }
        startTap()
    }

    func deactivate() {
        activeProfile = nil
        activeSerial = nil
        targetProcessIdentifier = nil
        stopTap()
    }

    private func startTap() {
        let mask = 1 << CGEventType.keyDown.rawValue
        let selfPointer = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(mask),
            callback: { _, type, event, userInfo in
                guard let userInfo else { return Unmanaged.passRetained(event) }
                let engine = Unmanaged<KeymapEngine>.fromOpaque(userInfo).takeUnretainedValue()
                return engine.handle(type: type, event: event)
            },
            userInfo: selfPointer
        ) else {
            print("KeymapEngine: 创建事件监听失败,请检查「系统设置 -> 隐私与安全性 -> 辅助功能」授权。")
            return
        }
        eventTap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    private func stopTap() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
    }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        guard type == .keyDown,
              let profile = activeProfile,
              let serial = activeSerial,
              let targetPID = targetProcessIdentifier,
              NSWorkspace.shared.frontmostApplication?.processIdentifier == targetPID
        else {
            return Unmanaged.passRetained(event)
        }
        let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        guard let binding = profile.bindings.first(where: { $0.keyCode == keyCode }) else {
            return Unmanaged.passRetained(event)
        }
        dispatchAction(binding.action, serial: serial)
        return nil // 消费该按键,不再传给模拟器窗口本身
    }

    private func dispatchAction(_ action: KeymapAction, serial: String) {
        let (w, h) = screenSize
        switch action {
        case .tap(let x, let y):
            adb.tap(serial: serial, x: Int(x * Double(w)), y: Int(y * Double(h)))
        case .swipe(let x1, let y1, let x2, let y2, let duration):
            adb.swipe(
                serial: serial,
                x1: Int(x1 * Double(w)), y1: Int(y1 * Double(h)),
                x2: Int(x2 * Double(w)), y2: Int(y2 * Double(h)),
                durationMS: duration
            )
        case .androidKeyEvent(let code):
            adb.keyEvent(serial: serial, code: code)
        }
    }
}
