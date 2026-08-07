import Foundation
import SwiftUI

/// 应用级全局状态:SDK 探测结果、AVD 列表,以及各服务/管理器单例。
@MainActor
final class AppState: ObservableObject {
    @Published var sdk: AndroidSDKPaths?
    @Published var avds: [AndroidVirtualDevice] = []
    @Published var sdkError: String?

    let store = InstanceStore()
    private(set) var adb: ADBService?
    private(set) var avdManager: AVDManager?
    private(set) var processManager: EmulatorProcessManager?
    private(set) var keymapEngine: KeymapEngine?
    private(set) var sharedFolderManager: SharedFolderManager?

    init() {
        reloadSDK()
    }

    func reloadSDK() {
        guard let paths = SDKLocator.locate() else {
            sdk = nil
            sdkError = SDKLocatorError.notFound.localizedDescription
            return
        }
        sdk = paths
        sdkError = nil
        let adbService = ADBService(adbPath: paths.adb.path)
        adb = adbService
        avdManager = AVDManager(sdk: paths)
        processManager = EmulatorProcessManager(sdk: paths, adb: adbService)
        keymapEngine = KeymapEngine(adb: adbService)
        sharedFolderManager = SharedFolderManager(adb: adbService)
        refreshAVDs()
        syncInstancesWithAVDs()
    }

    func refreshAVDs() {
        avds = avdManager?.listAVDs() ?? []
    }

    /// 保证每个已存在的 AVD 至少对应一个"实例"记录,便于首次运行时也能直接看到已有虚拟设备。
    func syncInstancesWithAVDs() {
        for avd in avds where !store.instances.contains(where: { $0.avdName == avd.name }) {
            store.upsert(EmulatorInstance(displayName: avd.name, avdName: avd.name))
        }
    }
}
