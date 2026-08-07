import SwiftUI

struct RootManagementView: View {
    @EnvironmentObject var appState: AppState
    let instance: EmulatorInstance
    @Environment(\.dismiss) private var dismiss

    @State private var isRooted = false
    @State private var isChecking = false
    @State private var message: String?

    private var serial: String? {
        appState.processManager?.serial(for: instance.id)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Root 管理 · \(instance.displayName)").font(.title3.bold())

            if serial == nil {
                Text("请先启动实例后再管理 Root 权限。").foregroundStyle(.secondary)
            } else {
                HStack {
                    Circle()
                        .fill(isRooted ? Color.green : Color.secondary)
                        .frame(width: 10, height: 10)
                    Text(isRooted ? "adbd 已以 root 身份运行" : "adbd 未以 root 身份运行")
                    Spacer()
                    if isChecking {
                        ProgressView().controlSize(.small)
                    }
                }

                Text("注意: 只有 AOSP / google_apis(非 Google Play)的 userdebug 系统镜像支持 adb root;\nGoogle Play 镜像出于安全策略会拒绝 root。")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack {
                    Button("启用 Root (adb root)") { toggleRoot(enable: true) }
                        .disabled(isChecking || isRooted)
                    Button("取消 Root (adb unroot)") { toggleRoot(enable: false) }
                        .disabled(isChecking || !isRooted)
                    Button("重新挂载 /system 可写") { remount() }
                        .disabled(isChecking || !isRooted)
                }
            }

            if let message {
                Text(message).font(.caption).foregroundStyle(.orange)
            }

            HStack {
                Spacer()
                Button("刷新状态") { refreshStatus() }
                Button("关闭") { dismiss() }
            }
        }
        .padding()
        .frame(width: 460)
        .onAppear(perform: refreshStatus)
    }

    private func refreshStatus() {
        guard let serial, let adb = appState.adb else { return }
        Task.detached(priority: .userInitiated) {
            let rooted = adb.isRootShell(serial: serial)
            await MainActor.run { isRooted = rooted }
        }
    }

    private func toggleRoot(enable: Bool) {
        guard let serial, let adb = appState.adb else { return }
        isChecking = true
        message = nil
        Task.detached(priority: .userInitiated) {
            do {
                if enable {
                    try adb.root(serial: serial)
                } else {
                    try adb.unroot(serial: serial)
                }
                // adb root/unroot 会重启 adbd,稍等片刻再查询状态。
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                let rooted = adb.isRootShell(serial: serial)
                await MainActor.run {
                    isRooted = rooted
                    isChecking = false
                    if enable {
                        message = rooted ? "已切换为 root shell" : "系统镜像可能不支持 root,请查看上方说明"
                    } else {
                        message = "已取消 root"
                    }
                }
            } catch {
                await MainActor.run {
                    isChecking = false
                    message = "操作失败: \(error.localizedDescription)"
                }
            }
        }
    }

    private func remount() {
        guard let serial, let adb = appState.adb else { return }
        isChecking = true
        Task.detached(priority: .userInitiated) {
            do {
                let output = try adb.remount(serial: serial)
                await MainActor.run {
                    isChecking = false
                    message = output.isEmpty ? "remount 完成" : output
                }
            } catch {
                await MainActor.run {
                    isChecking = false
                    message = "remount 失败: \(error.localizedDescription)"
                }
            }
        }
    }
}
