import SwiftUI

/// 系统镜像管理界面:浏览 sdkmanager 已知的全部 Android 系统镜像,支持一键下载安装。
struct SystemImageManagerView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var packages: [SystemImagePackage] = []
    @State private var showAllArchitectures = false
    @State private var downloadingIds: Set<String> = []
    @State private var messages: [String: String] = [:]
    @State private var isLoading = false
    @State private var loadError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("系统镜像管理").font(.title3.bold())
                Spacer()
                if isLoading {
                    ProgressView().controlSize(.small)
                }
                Button("刷新") { reload() }
                Button("关闭") { dismiss() }
            }

            Toggle("显示所有 CPU 架构(默认只显示与本机 \(HostArchitecture.compatibleABI) 兼容的镜像)", isOn: $showAllArchitectures)
                .font(.caption)

            if let loadError {
                Text(loadError).font(.caption).foregroundStyle(.red)
            }

            List {
                ForEach(groupedByAPI, id: \.api) { group in
                    Section("Android API \(group.api)") {
                        ForEach(group.packages) { pkg in
                            row(pkg)
                        }
                    }
                }
            }
        }
        .padding()
        .frame(width: 640, height: 560)
        .onAppear(perform: reload)
    }

    private var groupedByAPI: [(api: String, packages: [SystemImagePackage])] {
        let filtered = packages.filter { showAllArchitectures || $0.isHostCompatible }
        let groups = Dictionary(grouping: filtered, by: { $0.apiLevel })
        return groups.keys
            .sorted { lhs, rhs in
                let lNum = Int(lhs.prefix { $0.isNumber }) ?? 0
                let rNum = Int(rhs.prefix { $0.isNumber }) ?? 0
                return lNum == rNum ? lhs > rhs : lNum > rNum
            }
            .map { key in (api: key, packages: groups[key]!.sorted { $0.variant < $1.variant }) }
    }

    private func row(_ pkg: SystemImagePackage) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(pkg.description).font(.callout)
                Text(pkg.id).font(.system(.caption2, design: .monospaced)).foregroundStyle(.secondary)
                if let msg = messages[pkg.id] {
                    Text(msg)
                        .font(.caption2)
                        .foregroundStyle(msg.contains("失败") ? .red : .secondary)
                }
            }
            Spacer()
            statusView(pkg)
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private func statusView(_ pkg: SystemImagePackage) -> some View {
        if !pkg.isHostCompatible {
            Text("架构不兼容").font(.caption2).foregroundStyle(.orange)
        } else if pkg.isInstalled {
            Label("已安装", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.caption)
        } else if downloadingIds.contains(pkg.id) {
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text("下载中…").font(.caption)
            }
        } else {
            Button("下载") { download(pkg) }
                .disabled(!downloadingIds.isEmpty)
        }
    }

    private func reload() {
        guard let avdManager = appState.avdManager else { return }
        isLoading = true
        loadError = nil
        Task.detached(priority: .userInitiated) {
            do {
                let list = try avdManager.listAllSystemImages()
                await MainActor.run {
                    packages = list
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    loadError = "获取镜像列表失败: \(error.localizedDescription)"
                    isLoading = false
                }
            }
        }
    }

    private func download(_ pkg: SystemImagePackage) {
        guard let avdManager = appState.avdManager else { return }
        downloadingIds.insert(pkg.id)
        messages[pkg.id] = nil
        Task.detached(priority: .userInitiated) {
            do {
                try avdManager.installSystemImage(pkg.id)
                await MainActor.run {
                    downloadingIds.remove(pkg.id)
                    messages[pkg.id] = "安装完成"
                    reload()
                }
            } catch {
                await MainActor.run {
                    downloadingIds.remove(pkg.id)
                    messages[pkg.id] = "安装失败: \(error.localizedDescription)"
                }
            }
        }
    }
}
