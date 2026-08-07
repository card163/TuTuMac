import Foundation

/// 封装 adb 常用操作:设备列表、APK 安装、输入注入、截图、录屏。
final class ADBService {
    let adbPath: String

    init(adbPath: String) {
        self.adbPath = adbPath
    }

    func devices() -> [String] {
        guard let output = try? ShellRunner.run(adbPath, ["devices"]) else { return [] }
        return output
            .split(separator: "\n")
            .dropFirst()
            .compactMap { line -> String? in
                let parts = line.split(separator: "\t")
                guard parts.count == 2, parts[1] == "device" else { return nil }
                return String(parts[0])
            }
    }

    @discardableResult
    func installAPK(serial: String, apkPath: String) throws -> String {
        try ShellRunner.run(adbPath, ["-s", serial, "install", "-r", apkPath])
    }

    /// 在设备上创建目录(用于共享文件夹等场景,提前确保远端目录存在)。
    @discardableResult
    func makeRemoteDirectory(serial: String, remotePath: String) throws -> String {
        try ShellRunner.run(adbPath, ["-s", serial, "shell", "mkdir", "-p", remotePath])
    }

    /// 把本地文件/目录推送到设备(目录会递归推送)。
    @discardableResult
    func push(serial: String, localPath: String, remotePath: String) throws -> String {
        try ShellRunner.run(adbPath, ["-s", serial, "push", localPath, remotePath])
    }

    /// 把设备上的文件/目录拉取到本地(目录会递归拉取)。
    @discardableResult
    func pull(serial: String, remotePath: String, localPath: String) throws -> String {
        try ShellRunner.run(adbPath, ["-s", serial, "pull", remotePath, localPath])
    }

    /// 列出设备上某目录的直接子项(文件/文件夹名,不含 . 和 ..)。
    func listRemoteEntries(serial: String, remotePath: String) -> [String] {
        guard let output = try? ShellRunner.run(adbPath, ["-s", serial, "shell", "ls", "-1", remotePath]) else { return [] }
        return output
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    @discardableResult
    func root(serial: String) throws -> String {
        try ShellRunner.run(adbPath, ["-s", serial, "root"])
    }

    @discardableResult
    func unroot(serial: String) throws -> String {
        try ShellRunner.run(adbPath, ["-s", serial, "unroot"])
    }

    /// 将 /system 等分区重新挂载为可写(需先 root 成功)。
    @discardableResult
    func remount(serial: String) throws -> String {
        try ShellRunner.run(adbPath, ["-s", serial, "remount"])
    }

    /// 通过 `adb shell id` 判断当前 adbd 是否以 root 身份运行。
    func isRootShell(serial: String) -> Bool {
        guard let output = try? ShellRunner.run(adbPath, ["-s", serial, "shell", "id"]) else { return false }
        return output.contains("uid=0")
    }

    func tap(serial: String, x: Int, y: Int) {
        _ = try? ShellRunner.run(adbPath, ["-s", serial, "shell", "input", "tap", "\(x)", "\(y)"])
    }

    func swipe(serial: String, x1: Int, y1: Int, x2: Int, y2: Int, durationMS: Int) {
        _ = try? ShellRunner.run(adbPath, ["-s", serial, "shell", "input", "swipe", "\(x1)", "\(y1)", "\(x2)", "\(y2)", "\(durationMS)"])
    }

    func keyEvent(serial: String, code: Int) {
        _ = try? ShellRunner.run(adbPath, ["-s", serial, "shell", "input", "keyevent", "\(code)"])
    }

    func screenSize(serial: String) -> (width: Int, height: Int)? {
        guard let output = try? ShellRunner.run(adbPath, ["-s", serial, "shell", "wm", "size"]) else { return nil }
        guard let range = output.range(of: "\\d+x\\d+", options: .regularExpression) else { return nil }
        let parts = output[range].split(separator: "x")
        guard parts.count == 2, let w = Int(parts[0]), let h = Int(parts[1]) else { return nil }
        return (w, h)
    }

    @discardableResult
    func screenshot(serial: String, to fileURL: URL) throws -> URL {
        FileManager.default.createFile(atPath: fileURL.path, contents: nil)
        let handle = try FileHandle(forWritingTo: fileURL)
        defer { try? handle.close() }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: adbPath)
        process.arguments = ["-s", serial, "exec-out", "screencap", "-p"]
        process.standardOutput = handle
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        return fileURL
    }

    /// 开始录屏,返回可用于停止的 Process 句柄(远端文件默认写到 /sdcard)。
    func startScreenRecord(serial: String, remotePath: String = "/sdcard/tutumac_record.mp4") throws -> Process {
        try ShellRunner.spawn(adbPath, ["-s", serial, "shell", "screenrecord", "--bit-rate", "8000000", remotePath])
    }

    /// 停止录屏(向 adb 客户端发送 SIGINT,adb 会转发使远端 screenrecord 正常收尾),并拉取文件到本地。
    func stopScreenRecord(process: Process, serial: String, remotePath: String = "/sdcard/tutumac_record.mp4", pullTo localURL: URL) throws {
        process.interrupt()
        process.waitUntilExit()
        Thread.sleep(forTimeInterval: 1.0)
        try ShellRunner.run(adbPath, ["-s", serial, "pull", remotePath, localURL.path])
        _ = try? ShellRunner.run(adbPath, ["-s", serial, "shell", "rm", remotePath])
    }
}
