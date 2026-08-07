import SwiftUI

struct KeymapEditorView: View {
    @EnvironmentObject var appState: AppState
    let instance: EmulatorInstance
    @Environment(\.dismiss) private var dismiss

    @State private var profile: KeymapProfile
    @State private var pendingPoint: CGPoint?
    @State private var message: String?
    @State private var isEngineActive = false

    init(instance: EmulatorInstance) {
        self.instance = instance
        _profile = State(initialValue: KeymapProfile(name: "\(instance.displayName) 默认映射", bindings: []))
    }

    private var avd: AndroidVirtualDevice? {
        appState.avds.first { $0.name == instance.avdName }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("按键映射 · \(instance.displayName)").font(.title3.bold())
            Text("点击下方屏幕预览确定触控点,再按下要绑定的按键。")
                .font(.caption).foregroundStyle(.secondary)

            screenPreview

            List {
                ForEach(profile.bindings) { binding in
                    HStack {
                        Text(binding.label).frame(width: 60, alignment: .leading)
                        Text(describe(binding.action)).font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Button(role: .destructive) {
                            profile.bindings.removeAll { $0.id == binding.id }
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                    }
                }
            }
            .frame(minHeight: 140)

            engineSection

            if let message {
                Text(message).font(.caption).foregroundStyle(.orange)
            }

            HStack {
                Spacer()
                Button("关闭") { dismiss() }
                Button("保存映射") { save() }.buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(width: 480, height: 640)
        .onAppear(perform: loadExisting)
        .background(KeyCaptureView { keyCode, characters in
            handleKeyCapture(keyCode: keyCode, label: characters)
        })
    }

    @ViewBuilder
    private var engineSection: some View {
        if let pm = appState.processManager, case .running = pm.status(for: instance.id) {
            Divider()
            Button(isEngineActive ? "停止试用映射" : "启用映射到当前实例") {
                toggleEngine()
            }
            if !KeymapEngine.hasAccessibilityPermission {
                Text("需要在「系统设置 → 隐私与安全性 → 辅助功能」中为本 App 授权,才能全局捕获按键。")
                    .font(.caption).foregroundStyle(.orange)
                Button("请求辅助功能权限") { KeymapEngine.requestAccessibilityPermission() }
            }
        }
    }

    private var screenPreview: some View {
        GeometryReader { geo in
            let aspect = CGFloat(avd?.lcdHeight ?? 1920) / CGFloat(avd?.lcdWidth ?? 1080)
            let width = min(geo.size.width, geo.size.height / aspect)
            let height = width * aspect
            ZStack {
                Rectangle()
                    .fill(Color.black.opacity(0.85))
                    .frame(width: width, height: height)
                ForEach(profile.bindings) { binding in
                    if case .tap(let x, let y) = binding.action {
                        Circle()
                            .fill(Color.accentColor)
                            .frame(width: 10, height: 10)
                            .position(x: x * width, y: y * height)
                        Text(binding.label)
                            .font(.caption2)
                            .foregroundStyle(.white)
                            .position(x: x * width, y: y * height - 12)
                    }
                }
                if let pendingPoint {
                    Circle()
                        .stroke(Color.yellow, lineWidth: 2)
                        .frame(width: 14, height: 14)
                        .position(x: pendingPoint.x * width, y: pendingPoint.y * height)
                }
            }
            .frame(width: width, height: height)
            .position(x: geo.size.width / 2, y: geo.size.height / 2)
            .contentShape(Rectangle())
            .onTapGesture { location in
                pendingPoint = CGPoint(x: location.x / width, y: location.y / height)
                message = "已选取触控点,请按下要绑定的按键"
            }
        }
        .frame(height: 260)
    }

    private func handleKeyCapture(keyCode: UInt16, label: String) {
        guard let pendingPoint else { return }
        let binding = KeyBinding(keyCode: keyCode, label: label, action: .tap(x: pendingPoint.x, y: pendingPoint.y))
        profile.bindings.append(binding)
        self.pendingPoint = nil
        message = "已绑定按键 \(label)"
    }

    private func describe(_ action: KeymapAction) -> String {
        switch action {
        case .tap(let x, let y): return String(format: "点击 (%.2f, %.2f)", x, y)
        case .swipe: return "滑动"
        case .androidKeyEvent(let code): return "按键事件 \(code)"
        }
    }

    private func loadExisting() {
        if let id = instance.keymapProfileID, let existing = appState.store.keymapProfiles.first(where: { $0.id == id }) {
            profile = existing
        }
    }

    private func save() {
        appState.store.upsert(profile)
        var updated = instance
        updated.keymapProfileID = profile.id
        appState.store.upsert(updated)
        message = "映射已保存"
    }

    private func toggleEngine() {
        guard let engine = appState.keymapEngine,
              let pm = appState.processManager,
              let serial = pm.serial(for: instance.id),
              let pid = pm.processIdentifier(for: instance.id) else { return }
        if isEngineActive {
            engine.deactivate()
            isEngineActive = false
            message = "已停止映射"
        } else {
            let size = appState.adb?.screenSize(serial: serial) ?? (avd?.lcdWidth ?? 1080, avd?.lcdHeight ?? 1920)
            engine.activate(profile: profile, serial: serial, targetPID: pid, screenSize: size)
            isEngineActive = true
            message = "映射已启用,切到模拟器窗口后按键生效"
        }
    }
}
