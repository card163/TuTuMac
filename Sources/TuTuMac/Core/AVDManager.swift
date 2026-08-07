import Foundation

enum AVDManagerError: Error, LocalizedError {
    case parseFailed(String)

    var errorDescription: String? {
        switch self {
        case .parseFailed(let detail): return "操作失败: \(detail)"
        }
    }
}

/// 负责 AVD(Android 虚拟设备)的增删改查,是"模拟器实例"在磁盘上的真实载体。
final class AVDManager {
    private let sdk: AndroidSDKPaths
    private let avdRootDir: URL

    init(sdk: AndroidSDKPaths, avdRootDir: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".android/avd")) {
        self.sdk = sdk
        self.avdRootDir = avdRootDir
    }

    func listAVDs() -> [AndroidVirtualDevice] {
        let fm = FileManager.default
        guard let iniFiles = try? fm.contentsOfDirectory(at: avdRootDir, includingPropertiesForKeys: nil) else { return [] }
        var result: [AndroidVirtualDevice] = []
        for iniURL in iniFiles where iniURL.pathExtension == "ini" {
            let name = iniURL.deletingPathExtension().lastPathComponent
            guard let topINI = try? ConfigINI(contentsOf: iniURL), let pathString = topINI["path"] else { continue }
            let avdDir = URL(fileURLWithPath: pathString)
            let configURL = avdDir.appendingPathComponent("config.ini")
            guard let config = try? ConfigINI(contentsOf: configURL) else { continue }
            let (api, abiFromPath) = Self.parseSystemImagePath(config["image.sysdir.1"] ?? "")
            result.append(AndroidVirtualDevice(
                name: name,
                avdDirectory: avdDir,
                iniFile: iniURL,
                deviceProfile: config["hw.device.name"] ?? "unknown",
                apiLevel: api,
                abi: config["abi.type"] ?? abiFromPath,
                isPlayStoreEnabled: (config["PlayStore.enabled"] ?? "no") == "yes",
                ramSizeMB: Int(config["hw.ramSize"] ?? "") ?? 1536,
                cpuCoreCount: Int(config["hw.cpu.ncore"] ?? "") ?? 2,
                lcdWidth: Int(config["hw.lcd.width"] ?? "") ?? 1080,
                lcdHeight: Int(config["hw.lcd.height"] ?? "") ?? 1920,
                lcdDensity: Int(config["hw.lcd.density"] ?? "") ?? 420,
                gpuMode: config["hw.gpu.mode"] ?? "auto",
                hostKeyboardEnabled: (config["hw.keyboard"] ?? "no") == "yes"
            ))
        }
        return result.sorted { $0.name < $1.name }
    }

    private static func parseSystemImagePath(_ path: String) -> (api: String, abi: String) {
        // 形如 .../system-images/android-34/google_apis_playstore/arm64-v8a/
        let parts = path.split(separator: "/")
        var api = "unknown"
        var abi = "unknown"
        for (index, part) in parts.enumerated() {
            if part.hasPrefix("android-") { api = part.replacingOccurrences(of: "android-", with: "") }
            if index == parts.count - 1 { abi = String(part) }
        }
        return (api, abi)
    }

    func installedSystemImages() throws -> [String] {
        let output = try ShellRunner.run(sdk.sdkmanager.path, ["--list_installed"])
        return output
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { $0.hasPrefix("system-images;") }
            .compactMap { line -> String? in
                line.split(separator: "|").first.map { $0.trimmingCharacters(in: .whitespaces) }
            }
    }

    /// 列出 sdkmanager 已知的全部系统镜像(已安装 + 可下载),用于「系统镜像管理」界面。
    func listAllSystemImages() throws -> [SystemImagePackage] {
        let output = try ShellRunner.run(sdk.sdkmanager.path, ["--list"])
        guard let installedHeader = output.range(of: "Installed packages:"),
              let availableHeader = output.range(of: "Available Packages:") else {
            return []
        }
        let installedSection = output[installedHeader.upperBound..<availableHeader.lowerBound]
        let availableSection = output[availableHeader.upperBound...]

        var byId: [String: SystemImagePackage] = [:]
        for pkg in Self.parseSystemImageLines(String(availableSection), isInstalled: false) {
            byId[pkg.id] = pkg
        }
        // 已安装的优先覆盖(同一 id 理论上不会同时出现在两个 section,这里只是保险)。
        for pkg in Self.parseSystemImageLines(String(installedSection), isInstalled: true) {
            byId[pkg.id] = pkg
        }
        return byId.values.sorted { $0.id < $1.id }
    }

    private static func parseSystemImageLines(_ section: String, isInstalled: Bool) -> [SystemImagePackage] {
        section
            .split(separator: "\n")
            .compactMap { line -> SystemImagePackage? in
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                guard trimmed.hasPrefix("system-images;") else { return nil }
                let columns = trimmed.split(separator: "|").map { $0.trimmingCharacters(in: .whitespaces) }
                guard let id = columns.first else { return nil }
                let parts = id.split(separator: ";")
                guard parts.count == 4 else { return nil }
                return SystemImagePackage(
                    id: id,
                    apiLevel: String(parts[1]).replacingOccurrences(of: "android-", with: ""),
                    variant: String(parts[2]),
                    abi: String(parts[3]),
                    description: columns.count >= 3 ? columns[2] : "",
                    isInstalled: isInstalled
                )
            }
    }

    /// 下载并安装一个系统镜像(会自动接受许可确认提示)。
    /// `onOutputLine` 会被高频调用、可能在任意后台线程,用于解析下载进度等实时信息。
    @discardableResult
    func installSystemImage(_ packageId: String, onOutputLine: @escaping (String) -> Void = { _ in }) throws -> String {
        try ShellRunner.streamAutoAcceptingPrompts(sdk.sdkmanager.path, [packageId], onOutput: onOutputLine)
    }

    @discardableResult
    func createAVD(name: String, systemImage: String, device: String, sdcardSizeMB: Int = 512) throws -> String {
        let output = try ShellRunner.run(sdk.avdmanager.path, [
            "create", "avd",
            "-n", name,
            "-k", systemImage,
            "-d", device,
            "-c", "\(sdcardSizeMB)M",
            "--force"
        ])
        // avdmanager 命令行创建的 AVD 默认 hw.keyboard=no,电脑物理键盘无法直接输入,这里提前打开。
        try? enableHostKeyboard(avdName: name)
        return output
    }

    /// 写入 hw.keyboard=yes,让电脑物理键盘可以直接向虚拟机输入文字(否则只会弹软键盘)。
    func enableHostKeyboard(avdName: String) throws {
        let configURL = avdRootDir.appendingPathComponent("\(avdName).avd/config.ini")
        var config = try ConfigINI(contentsOf: configURL)
        config["hw.keyboard"] = "yes"
        try config.write(to: configURL)
    }

    func deleteAVD(name: String) throws {
        try ShellRunner.run(sdk.avdmanager.path, ["delete", "avd", "-n", name])
    }

    /// 克隆一个 AVD:复制磁盘上的 .ini 与 .avd 目录,并重写内部引用的路径/名称。
    func cloneAVD(sourceName: String, newName: String) throws {
        let fm = FileManager.default
        let sourceINI = avdRootDir.appendingPathComponent("\(sourceName).ini")
        let targetINI = avdRootDir.appendingPathComponent("\(newName).ini")
        guard !fm.fileExists(atPath: targetINI.path) else {
            throw AVDManagerError.parseFailed("目标实例名 \(newName) 已存在")
        }
        var topINI = try ConfigINI(contentsOf: sourceINI)
        guard let sourcePathString = topINI["path"] else { throw AVDManagerError.parseFailed("无法读取 \(sourceName) 的路径") }
        let sourceDir = URL(fileURLWithPath: sourcePathString)
        let targetDir = avdRootDir.appendingPathComponent("\(newName).avd")

        try fm.copyItem(at: sourceDir, to: targetDir)

        topINI["path"] = targetDir.path
        topINI["path.rel"] = "avd/\(newName).avd"
        try topINI.write(to: targetINI)

        let configURL = targetDir.appendingPathComponent("config.ini")
        var config = try ConfigINI(contentsOf: configURL)
        config["avd.ini.displayname"] = newName
        try config.write(to: configURL)
    }

    /// 修改性能相关设置;实例需处于停止状态,设置在下次启动时生效。
    func applyPerformanceProfile(_ profile: PerformanceProfile, to avd: AndroidVirtualDevice) throws {
        let configURL = avd.avdDirectory.appendingPathComponent("config.ini")
        var config = try ConfigINI(contentsOf: configURL)
        config["hw.ramSize"] = String(profile.ramSizeMB)
        config["hw.cpu.ncore"] = String(profile.cpuCoreCount)
        config["hw.gpu.mode"] = profile.gpuMode
        config["hw.lcd.width"] = String(profile.lcdWidth)
        config["hw.lcd.height"] = String(profile.lcdHeight)
        config["hw.lcd.density"] = String(profile.lcdDensity)
        config["hw.keyboard"] = profile.hostKeyboardEnabled ? "yes" : "no"
        try config.write(to: configURL)
    }
}
