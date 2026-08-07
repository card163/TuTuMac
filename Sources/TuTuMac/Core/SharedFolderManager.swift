import Foundation

/// 用"电脑本地目录 <-> adb push/pull"模拟出的共享文件夹功能。
///
/// 注意: 这不是像 VirtualBox 共享文件夹那样的实时挂载,而是显式的单向同步动作
/// (推送 / 拉取)。原因: Android 侧没有通用的网络文件系统客户端可以直接挂载电脑目录,
/// 真正做到实时双向挂载需要在虚拟机里跑一个额外的文件服务(如 SFTP/WebDAV)配合宿主机挂载,
/// 复杂度和风险都高出很多,对"共享文件夹"这个需求来说没必要。
final class SharedFolderManager {
    /// 设备上固定的共享目录,可在 Android 自带的「文件」App 的「内部存储」下找到。
    static let remotePath = "/sdcard/TuTuMac"

    private let adb: ADBService

    init(adb: ADBService) {
        self.adb = adb
    }

    /// 本机侧的共享目录,不存在会自动创建;在 Finder 里拖文件进出这个目录即可。
    func hostFolderURL(for instance: EmulatorInstance) -> URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("TuTuMac/SharedFolders/\(instance.avdName)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// 把电脑共享目录里的每一项内容推送到设备的 `remotePath` 下,让手机里能浏览到电脑文件。
    ///
    /// 之所以要逐项推送而不是整个目录一次性推送: `adb push <dir> <dst>` 会把
    /// `<dir>` 本身作为子文件夹放进 `<dst>`(类似 `cp -r`),而不是把目录内容平铺进
    /// `<dst>`,如果直接推送整个目录会在设备上多出一层无意义的子目录。
    @discardableResult
    func pushToDevice(serial: String, instance: EmulatorInstance) throws -> String {
        let hostFolder = hostFolderURL(for: instance)
        try adb.makeRemoteDirectory(serial: serial, remotePath: Self.remotePath)
        let children = (try? FileManager.default.contentsOfDirectory(at: hostFolder, includingPropertiesForKeys: nil)) ?? []
        guard !children.isEmpty else { return "共享目录为空,没有需要推送的文件。" }
        var outputs: [String] = []
        for child in children {
            let output = try adb.push(serial: serial, localPath: child.path, remotePath: "\(Self.remotePath)/\(child.lastPathComponent)")
            outputs.append(output)
        }
        return outputs.joined(separator: "\n")
    }

    /// 把设备 `remotePath` 目录下的每一项内容拉取到电脑共享目录,原因同上(避免多一层嵌套目录)。
    @discardableResult
    func pullFromDevice(serial: String, instance: EmulatorInstance) throws -> String {
        let hostFolder = hostFolderURL(for: instance)
        let entries = adb.listRemoteEntries(serial: serial, remotePath: Self.remotePath)
        guard !entries.isEmpty else { return "手机端共享目录为空,没有可拉取的文件。" }
        var outputs: [String] = []
        for entry in entries {
            let output = try adb.pull(serial: serial, remotePath: "\(Self.remotePath)/\(entry)", localPath: hostFolder.path)
            outputs.append(output)
        }
        return outputs.joined(separator: "\n")
    }
}
