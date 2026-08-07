import SwiftUI
import AppKit

struct SharedFolderView: View {
    @EnvironmentObject var appState: AppState
    let instance: EmulatorInstance
    @Environment(\.dismiss) private var dismiss

    @State private var isSyncing = false
    @State private var message: String?

    private var serial: String? {
        appState.processManager?.serial(for: instance.id)
    }

    private var hostFolder: URL? {
        appState.sharedFolderManager?.hostFolderURL(for: instance)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("共享文件夹 · \(instance.displayName)").font(.title3.bold())

            Text("不是实时挂载,而是手动/一键触发的双向同步:「推送到手机」把电脑目录整体复制到\n手机内部存储的 \(SharedFolderManager.remotePath);「从手机拉取」把手机该目录整体复制回电脑。")
                .font(.caption)
                .foregroundStyle(.secondary)

            if let hostFolder {
                HStack {
                    Text(hostFolder.path)
                        .font(.system(.caption, design: .monospaced))
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                    Button("在 Finder 中打开") {
                        NSWorkspace.shared.activateFileViewerSelecting([hostFolder])
                    }
                }
            }

            if serial == nil {
                Text("请先启动实例,再进行推送/拉取。").foregroundStyle(.secondary)
            }

            HStack {
                Button("推送到手机 →") { push() }
                    .disabled(serial == nil || isSyncing)
                Button("← 从手机拉取") { pull() }
                    .disabled(serial == nil || isSyncing)
                if isSyncing {
                    ProgressView().controlSize(.small)
                }
            }

            if let message {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .textSelection(.enabled)
            }

            HStack {
                Spacer()
                Button("关闭") { dismiss() }
            }
        }
        .padding()
        .frame(width: 480)
    }

    private func push() {
        guard let serial, let manager = appState.sharedFolderManager else { return }
        isSyncing = true
        message = nil
        Task.detached(priority: .userInitiated) {
            do {
                try manager.pushToDevice(serial: serial, instance: instance)
                await MainActor.run {
                    isSyncing = false
                    message = "已推送到手机 \(SharedFolderManager.remotePath),可在「文件」App 的内部存储中查看。"
                }
            } catch {
                await MainActor.run {
                    isSyncing = false
                    message = "推送失败: \(error.localizedDescription)"
                }
            }
        }
    }

    private func pull() {
        guard let serial, let manager = appState.sharedFolderManager else { return }
        isSyncing = true
        message = nil
        Task.detached(priority: .userInitiated) {
            do {
                try manager.pullFromDevice(serial: serial, instance: instance)
                await MainActor.run {
                    isSyncing = false
                    message = "已从手机拉取到电脑共享目录。"
                }
            } catch {
                await MainActor.run {
                    isSyncing = false
                    message = "拉取失败: \(error.localizedDescription)"
                }
            }
        }
    }
}
