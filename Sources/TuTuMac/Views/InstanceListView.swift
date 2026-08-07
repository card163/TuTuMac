import SwiftUI

struct InstanceListView: View {
    @EnvironmentObject var appState: AppState
    @Binding var selection: EmulatorInstance.ID?
    @Binding var showingCreateSheet: Bool

    var body: some View {
        List(selection: $selection) {
            ForEach(appState.store.instances) { instance in
                InstanceRowView(instance: instance)
                    .tag(instance.id)
                    .contextMenu {
                        Button("克隆实例") { clone(instance) }
                        Button("删除实例", role: .destructive) { delete(instance) }
                    }
            }
        }
        .navigationTitle("模拟器实例")
        .toolbar {
            ToolbarItem {
                Button {
                    showingCreateSheet = true
                } label: {
                    Label("新建实例", systemImage: "plus")
                }
            }
            ToolbarItem {
                Button {
                    appState.refreshAVDs()
                    appState.syncInstancesWithAVDs()
                } label: {
                    Label("刷新", systemImage: "arrow.clockwise")
                }
            }
        }
    }

    private func clone(_ instance: EmulatorInstance) {
        guard let avdManager = appState.avdManager else { return }
        let newName = "\(instance.avdName)_copy_\(Int(Date().timeIntervalSince1970))"
        do {
            try avdManager.cloneAVD(sourceName: instance.avdName, newName: newName)
            appState.refreshAVDs()
            appState.store.upsert(EmulatorInstance(displayName: newName, avdName: newName))
        } catch {
            print("克隆失败: \(error)")
        }
    }

    private func delete(_ instance: EmulatorInstance) {
        appState.processManager?.stop(instance: instance)
        try? appState.avdManager?.deleteAVD(name: instance.avdName)
        appState.store.remove(instance)
        appState.refreshAVDs()
    }
}
