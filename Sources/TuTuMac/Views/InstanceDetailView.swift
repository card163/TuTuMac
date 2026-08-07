import SwiftUI
import UniformTypeIdentifiers
import AppKit

struct InstanceDetailView: View {
    @EnvironmentObject var appState: AppState
    let instance: EmulatorInstance

    @State private var isDropTargeted = false
    @State private var lastMessage: String?
    @State private var isRecording = false
    @State private var recordProcess: Process?
    @State private var showingPerformance = false
    @State private var showingKeymap = false
    @State private var showingRoot = false
    @State private var showingSharedFolder = false

    private var avd: AndroidVirtualDevice? {
        appState.avds.first { $0.name == instance.avdName }
    }

    private var status: InstanceStatus {
        appState.processManager?.status(for: instance.id) ?? .stopped
    }

    private var isRunning: Bool {
        if case .running = status { return true }
        return false
    }

    private var startFailureMessage: String? {
        appState.processManager?.lastError[instance.id]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            if let avd {
                avdInfo(avd)
            }
            if let startFailureMessage {
                startFailureBanner(startFailureMessage)
            }
            dropZone
            if let lastMessage {
                Text(lastMessage).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding()
        .navigationTitle(instance.displayName)
        .toolbar {
            ToolbarItem { startStopButton }
            ToolbarItem {
                Button("性能设置") { showingPerformance = true }
            }
            ToolbarItem {
                Button("按键映射") { showingKeymap = true }
            }
            ToolbarItem {
                Button("Root 管理") { showingRoot = true }
            }
            ToolbarItem {
                Button("共享文件夹") { showingSharedFolder = true }
            }
            ToolbarItem {
                Button(action: takeScreenshot) {
                    Label("截图", systemImage: "camera")
                }.disabled(!isRunning)
            }
            ToolbarItem {
                Button(action: toggleRecording) {
                    Label(isRecording ? "停止录屏" : "开始录屏", systemImage: isRecording ? "record.circle.fill" : "record.circle")
                }.disabled(!isRunning)
            }
        }
        .sheet(isPresented: $showingPerformance) {
            PerformanceSettingsView(instance: instance)
        }
        .sheet(isPresented: $showingKeymap) {
            KeymapEditorView(instance: instance)
        }
        .sheet(isPresented: $showingRoot) {
            RootManagementView(instance: instance)
        }
        .sheet(isPresented: $showingSharedFolder) {
            SharedFolderView(instance: instance)
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(instance.displayName).font(.title2.bold())
                Text("AVD: \(instance.avdName)").foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private func avdInfo(_ avd: AndroidVirtualDevice) -> some View {
        GroupBox("设备信息") {
            VStack(alignment: .leading, spacing: 6) {
                Text("Android API \(avd.apiLevel) · \(avd.abi)")
                Text("分辨率: \(avd.lcdWidth) x \(avd.lcdHeight) @ \(avd.lcdDensity)dpi")
                Text("内存: \(avd.ramSizeMB) MB · CPU 核心: \(avd.cpuCoreCount)")
                Text("GPU 模式: \(avd.gpuMode)")
                Text("Google Play: \(avd.isPlayStoreEnabled ? "支持" : "不支持")")
            }
            .font(.callout)
        }
    }

    private func startFailureBanner(_ message: String) -> some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                Label("启动失败", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                Text(message)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                Button("在 Finder 中查看完整日志") {
                    guard let pm = appState.processManager else { return }
                    NSWorkspace.shared.activateFileViewerSelecting([pm.logFileURL(for: instance)])
                }
                .font(.caption)
            }
        }
    }

    private var dropZone: some View {
        RoundedRectangle(cornerRadius: 12)
            .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [6]))
            .foregroundStyle(isDropTargeted ? Color.accentColor : Color.secondary)
            .frame(height: 120)
            .overlay(
                VStack {
                    Image(systemName: "arrow.down.doc")
                    Text(isRunning ? "拖拽 APK 到此处安装" : "启动实例后可拖拽 APK 安装")
                }
                .foregroundStyle(.secondary)
            )
            .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
                handleDrop(providers)
            }
    }

    private var startStopButton: some View {
        Button(action: toggleRun) {
            Label(isRunning ? "停止" : "启动", systemImage: isRunning ? "stop.fill" : "play.fill")
        }
    }

    private func toggleRun() {
        guard let pm = appState.processManager else { return }
        if isRunning {
            pm.stop(instance: instance)
        } else {
            pm.start(instance: instance)
        }
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard isRunning, let serial = appState.processManager?.serial(for: instance.id), let adb = appState.adb else {
            lastMessage = "请先启动实例再安装 APK"
            return false
        }
        guard let provider = providers.first else { return false }
        _ = provider.loadObject(ofClass: URL.self) { url, _ in
            guard let url, url.pathExtension.lowercased() == "apk" else { return }
            Task.detached(priority: .userInitiated) {
                do {
                    try adb.installAPK(serial: serial, apkPath: url.path)
                    await MainActor.run { lastMessage = "安装成功: \(url.lastPathComponent)" }
                } catch {
                    await MainActor.run { lastMessage = "安装失败: \(error.localizedDescription)" }
                }
            }
        }
        return true
    }

    private func takeScreenshot() {
        guard let serial = appState.processManager?.serial(for: instance.id), let adb = appState.adb else { return }
        let dir = FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("TuTuMac", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let file = dir.appendingPathComponent("\(instance.displayName)-\(Int(Date().timeIntervalSince1970)).png")
        Task.detached(priority: .userInitiated) {
            do {
                try adb.screenshot(serial: serial, to: file)
                await MainActor.run { lastMessage = "截图已保存: \(file.path)" }
            } catch {
                await MainActor.run { lastMessage = "截图失败: \(error.localizedDescription)" }
            }
        }
    }

    private func toggleRecording() {
        guard let serial = appState.processManager?.serial(for: instance.id), let adb = appState.adb else { return }
        if isRecording {
            let dir = FileManager.default.urls(for: .moviesDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("TuTuMac", isDirectory: true)
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let file = dir.appendingPathComponent("\(instance.displayName)-\(Int(Date().timeIntervalSince1970)).mp4")
            guard let process = recordProcess else { return }
            isRecording = false
            recordProcess = nil
            Task.detached(priority: .userInitiated) {
                do {
                    try adb.stopScreenRecord(process: process, serial: serial, pullTo: file)
                    await MainActor.run { lastMessage = "录屏已保存: \(file.path)" }
                } catch {
                    await MainActor.run { lastMessage = "录屏保存失败: \(error.localizedDescription)" }
                }
            }
        } else {
            do {
                recordProcess = try adb.startScreenRecord(serial: serial)
                isRecording = true
                lastMessage = "开始录屏…"
            } catch {
                lastMessage = "启动录屏失败: \(error.localizedDescription)"
            }
        }
    }
}
