import Foundation

/// 管理各实例对应的 emulator 子进程:启动、等待其在 adb 中上线、停止。
@MainActor
final class EmulatorProcessManager: ObservableObject {
    @Published private(set) var statuses: [UUID: InstanceStatus] = [:]
    /// 上一次启动失败时的诊断信息(emulator 日志尾部),供 UI 展示。
    @Published private(set) var lastError: [UUID: String] = [:]

    private let sdk: AndroidSDKPaths
    private let adb: ADBService
    private var processes: [UUID: Process] = [:]
    private var ports: [UUID: Int] = [:]
    private var nextPort = 5554

    init(sdk: AndroidSDKPaths, adb: ADBService) {
        self.sdk = sdk
        self.adb = adb
    }

    func status(for instanceID: UUID) -> InstanceStatus {
        statuses[instanceID] ?? .stopped
    }

    func serial(for instanceID: UUID) -> String? {
        if case .running(let serial) = status(for: instanceID) { return serial }
        return nil
    }

    func processIdentifier(for instanceID: UUID) -> pid_t? {
        processes[instanceID]?.processIdentifier
    }

    /// 本次启动写入的 emulator 日志文件路径,便于 UI 提供"查看日志"入口。
    func logFileURL(for instance: EmulatorInstance) -> URL {
        Self.logDirectory().appendingPathComponent("\(instance.avdName).log")
    }

    private static func logDirectory() -> URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("TuTuMac/Logs", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    func start(instance: EmulatorInstance) {
        guard status(for: instance.id) == .stopped else { return }
        statuses[instance.id] = .starting
        lastError[instance.id] = nil

        let port = allocatePort()
        ports[instance.id] = port
        let serial = "emulator-\(port)"
        let logURL = logFileURL(for: instance)

        do {
            let process = try ShellRunner.spawnWithLog(sdk.emulator.path, [
                "-avd", instance.avdName,
                "-port", "\(port)",
                "-netdelay", "none",
                "-netspeed", "full"
            ], logFileURL: logURL)
            processes[instance.id] = process
            process.terminationHandler = { [weak self] proc in
                Task { @MainActor in
                    self?.handleTermination(instanceID: instance.id, exitCode: proc.terminationStatus, logURL: logURL)
                }
            }
            waitForBoot(instanceID: instance.id, serial: serial)
        } catch {
            statuses[instance.id] = .stopped
            lastError[instance.id] = "启动失败: \(error.localizedDescription)"
        }
    }

    private func waitForBoot(instanceID: UUID, serial: String, attemptsLeft: Int = 90) {
        Task { @MainActor in
            guard self.processes[instanceID] != nil else { return }
            if self.adb.devices().contains(serial) {
                self.statuses[instanceID] = .running(serial: serial)
            } else if attemptsLeft > 0 {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                self.waitForBoot(instanceID: instanceID, serial: serial, attemptsLeft: attemptsLeft - 1)
            } else {
                self.lastError[instanceID] = "等待超过 90 秒仍未在 adb devices 中上线,已放弃等待并终止进程。"
                self.processes[instanceID]?.terminate()
                self.statuses[instanceID] = .stopped
                self.processes[instanceID] = nil
                self.ports[instanceID] = nil
            }
        }
    }

    func stop(instance: EmulatorInstance) {
        guard let serial = serial(for: instance.id) else {
            // 尚未完全启动就被要求停止,直接终止进程。
            processes[instance.id]?.terminate()
            return
        }
        statuses[instance.id] = .stopping
        let adbPath = adb.adbPath
        Task.detached(priority: .utility) {
            try? ShellRunner.run(adbPath, ["-s", serial, "emu", "kill"])
        }
    }

    private func handleTermination(instanceID: UUID, exitCode: Int32, logURL: URL) {
        // 只有在从未成功跑起来(未到 running 状态)就退出时,才当作启动失败展示日志。
        if case .running = statuses[instanceID] ?? .stopped {} else if exitCode != 0 {
            lastError[instanceID] = ShellRunner.tail(of: logURL, lines: 8) ?? "emulator 异常退出(exit code \(exitCode)),且未能读取日志。"
        }
        statuses[instanceID] = .stopped
        processes[instanceID] = nil
        ports[instanceID] = nil
    }

    private func allocatePort() -> Int {
        let used = Set(ports.values)
        var candidate = nextPort
        while used.contains(candidate) {
            candidate += 2 // emulator 要求偶数端口
        }
        nextPort = candidate + 2
        return candidate
    }
}
