import Foundation

/// 持久化"实例"和"按键映射方案"两类应用层数据(JSON,存于 Application Support)。
@MainActor
final class InstanceStore: ObservableObject {
    @Published var instances: [EmulatorInstance] = []
    @Published var keymapProfiles: [KeymapProfile] = []

    private let instancesURL: URL
    private let keymapsURL: URL

    init() {
        let supportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("TuTuMac", isDirectory: true)
        try? FileManager.default.createDirectory(at: supportDir, withIntermediateDirectories: true)
        instancesURL = supportDir.appendingPathComponent("instances.json")
        keymapsURL = supportDir.appendingPathComponent("keymaps.json")
        load()
    }

    func load() {
        if let data = try? Data(contentsOf: instancesURL) {
            instances = (try? JSONDecoder().decode([EmulatorInstance].self, from: data)) ?? []
        }
        if let data = try? Data(contentsOf: keymapsURL) {
            keymapProfiles = (try? JSONDecoder().decode([KeymapProfile].self, from: data)) ?? []
        }
    }

    func save() {
        if let data = try? JSONEncoder().encode(instances) {
            try? data.write(to: instancesURL, options: .atomic)
        }
        if let data = try? JSONEncoder().encode(keymapProfiles) {
            try? data.write(to: keymapsURL, options: .atomic)
        }
    }

    func upsert(_ instance: EmulatorInstance) {
        if let idx = instances.firstIndex(where: { $0.id == instance.id }) {
            instances[idx] = instance
        } else {
            instances.append(instance)
        }
        save()
    }

    func remove(_ instance: EmulatorInstance) {
        instances.removeAll { $0.id == instance.id }
        save()
    }

    func upsert(_ profile: KeymapProfile) {
        if let idx = keymapProfiles.firstIndex(where: { $0.id == profile.id }) {
            keymapProfiles[idx] = profile
        } else {
            keymapProfiles.append(profile)
        }
        save()
    }

    func removeKeymap(_ profile: KeymapProfile) {
        keymapProfiles.removeAll { $0.id == profile.id }
        save()
    }
}
