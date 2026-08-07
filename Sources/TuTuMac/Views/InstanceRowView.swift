import SwiftUI

struct InstanceRowView: View {
    @EnvironmentObject var appState: AppState
    let instance: EmulatorInstance

    private var status: InstanceStatus {
        appState.processManager?.status(for: instance.id) ?? .stopped
    }

    private var hasStartFailure: Bool {
        appState.processManager?.lastError[instance.id] != nil
    }

    var body: some View {
        HStack {
            Image(systemName: "ipad.landscape")
                .foregroundStyle(statusColor)
            VStack(alignment: .leading) {
                HStack(spacing: 4) {
                    Text(instance.displayName)
                        .font(.headline)
                    if hasStartFailure {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }
                Text(statusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button(action: toggle) {
                Image(systemName: isRunning ? "stop.fill" : "play.fill")
            }
            .buttonStyle(.borderless)
        }
        .padding(.vertical, 4)
    }

    private var isRunning: Bool {
        if case .running = status { return true }
        return false
    }

    private var statusText: String {
        switch status {
        case .stopped: return "已停止"
        case .starting: return "启动中…"
        case .running: return "运行中"
        case .stopping: return "停止中…"
        }
    }

    private var statusColor: Color {
        switch status {
        case .running: return .green
        case .starting, .stopping: return .orange
        case .stopped: return .secondary
        }
    }

    private func toggle() {
        guard let pm = appState.processManager else { return }
        if isRunning {
            pm.stop(instance: instance)
        } else {
            pm.start(instance: instance)
        }
    }
}
