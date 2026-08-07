import Foundation

/// 宿主 Mac 的 CPU 架构相关信息。
///
/// Android Emulator(QEMU2)在 Apple Silicon 上只能加速运行与宿主同架构的系统镜像
/// (arm64-v8a);反之亦然。挑错架构会直接启动失败(FATAL: Avd's CPU Architecture ... not supported)。
enum HostArchitecture {
    /// 与本机 CPU 兼容、emulator 能够加速运行的系统镜像 ABI。
    static var compatibleABI: String {
        #if arch(arm64)
        return "arm64-v8a"
        #else
        return "x86_64"
        #endif
    }
}
