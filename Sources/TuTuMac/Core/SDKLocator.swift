import Foundation

/// 已定位到的 Android SDK 及其中的核心可执行文件路径。
struct AndroidSDKPaths {
    let sdkRoot: URL
    let adb: URL
    let emulator: URL
    let avdmanager: URL
    let sdkmanager: URL
}

enum SDKLocatorError: Error, LocalizedError {
    case notFound

    var errorDescription: String? {
        "未找到 Android SDK,请安装 Android Studio / command line tools,或在设置中手动指定 SDK 路径。"
    }
}

/// 定位本机 Android SDK 及其中的 adb / emulator / avdmanager / sdkmanager。
enum SDKLocator {
    static let userDefaultsKey = "TuTuMac.customSDKRoot"

    static var candidateRoots: [URL] {
        var roots: [URL] = []
        if let custom = UserDefaults.standard.string(forKey: userDefaultsKey), !custom.isEmpty {
            roots.append(URL(fileURLWithPath: custom))
        }
        let env = ProcessInfo.processInfo.environment
        if let home = env["ANDROID_HOME"], !home.isEmpty {
            roots.append(URL(fileURLWithPath: home))
        }
        if let home = env["ANDROID_SDK_ROOT"], !home.isEmpty {
            roots.append(URL(fileURLWithPath: home))
        }
        let fileManagerHome = FileManager.default.homeDirectoryForCurrentUser
        roots.append(fileManagerHome.appendingPathComponent("Library/Android/sdk"))
        roots.append(URL(fileURLWithPath: "/opt/homebrew/share/android-commandlinetools"))
        roots.append(URL(fileURLWithPath: "/usr/local/share/android-commandlinetools"))
        return roots
    }

    static func locate() -> AndroidSDKPaths? {
        let fm = FileManager.default
        for root in candidateRoots {
            let adb = root.appendingPathComponent("platform-tools/adb")
            let emulator = root.appendingPathComponent("emulator/emulator")
            guard fm.isExecutableFile(atPath: adb.path), fm.isExecutableFile(atPath: emulator.path) else { continue }

            let avdmanagerCandidates = [
                root.appendingPathComponent("cmdline-tools/latest/bin/avdmanager"),
                root.appendingPathComponent("tools/bin/avdmanager")
            ]
            let sdkmanagerCandidates = [
                root.appendingPathComponent("cmdline-tools/latest/bin/sdkmanager"),
                root.appendingPathComponent("tools/bin/sdkmanager")
            ]
            guard let avdmanager = avdmanagerCandidates.first(where: { fm.isExecutableFile(atPath: $0.path) }) else { continue }
            let sdkmanager = sdkmanagerCandidates.first(where: { fm.isExecutableFile(atPath: $0.path) }) ?? sdkmanagerCandidates[0]

            return AndroidSDKPaths(sdkRoot: root, adb: adb, emulator: emulator, avdmanager: avdmanager, sdkmanager: sdkmanager)
        }
        return nil
    }
}
