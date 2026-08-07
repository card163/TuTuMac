import Foundation

/// sdkmanager 里的一个系统镜像包(不管是已安装还是可下载)。
struct SystemImagePackage: Identifiable, Hashable {
    var id: String // 完整包名,如 system-images;android-34;google_apis_playstore;arm64-v8a
    var apiLevel: String
    var variant: String // google_apis / google_apis_playstore / default / android-tv ...
    var abi: String
    var description: String
    var isInstalled: Bool

    /// 是否与本机 CPU 架构兼容,可以被 emulator 加速运行。
    var isHostCompatible: Bool {
        abi == HostArchitecture.compatibleABI
    }
}
