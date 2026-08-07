import SwiftUI

struct PerformanceSettingsView: View {
    @EnvironmentObject var appState: AppState
    let instance: EmulatorInstance
    @Environment(\.dismiss) private var dismiss

    @State private var profile = PerformanceProfile.default
    @State private var message: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("性能设置 · \(instance.displayName)").font(.title3.bold())

            Stepper("内存: \(profile.ramSizeMB) MB", value: $profile.ramSizeMB, in: 512...8192, step: 512)
            Stepper("CPU 核心数: \(profile.cpuCoreCount)", value: $profile.cpuCoreCount, in: 1...8)

            Picker("GPU 加速模式", selection: $profile.gpuMode) {
                Text("宿主机加速 (host)").tag("host")
                Text("软件渲染 (swiftshader_indirect)").tag("swiftshader_indirect")
                Text("自动 (auto)").tag("auto")
            }

            Toggle("启用电脑键盘直接输入(hw.keyboard)", isOn: $profile.hostKeyboardEnabled)
            Text("关闭时 Android 会认为没有物理键盘,文本框只能用弹出的软键盘输入。")
                .font(.caption).foregroundStyle(.secondary)

            HStack {
                Text("分辨率")
                TextField("宽", value: $profile.lcdWidth, format: .number).frame(width: 70)
                Text("x")
                TextField("高", value: $profile.lcdHeight, format: .number).frame(width: 70)
                Text("密度")
                TextField("dpi", value: $profile.lcdDensity, format: .number).frame(width: 60)
            }

            Text("提示: 实例需处于停止状态,设置才会在下次启动时生效。")
                .font(.caption).foregroundStyle(.secondary)

            if let message {
                Text(message).font(.caption).foregroundStyle(.secondary)
            }

            HStack {
                Spacer()
                Button("关闭") { dismiss() }
                Button("保存") { save() }.buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(width: 420)
        .onAppear(perform: loadCurrent)
    }

    private func loadCurrent() {
        guard let avd = appState.avds.first(where: { $0.name == instance.avdName }) else { return }
        profile = PerformanceProfile(
            ramSizeMB: avd.ramSizeMB, cpuCoreCount: avd.cpuCoreCount,
            lcdWidth: avd.lcdWidth, lcdHeight: avd.lcdHeight, lcdDensity: avd.lcdDensity,
            gpuMode: avd.gpuMode, hostKeyboardEnabled: avd.hostKeyboardEnabled
        )
    }

    private func save() {
        guard let avd = appState.avds.first(where: { $0.name == instance.avdName }),
              let avdManager = appState.avdManager else { return }
        if case .running = appState.processManager?.status(for: instance.id) ?? .stopped {
            message = "请先停止实例再修改性能设置"
            return
        }
        do {
            try avdManager.applyPerformanceProfile(profile, to: avd)
            appState.refreshAVDs()
            message = "已保存,下次启动生效"
        } catch {
            message = "保存失败: \(error.localizedDescription)"
        }
    }
}
