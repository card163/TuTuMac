import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var selection: EmulatorInstance.ID?
    @State private var showingCreateSheet = false
    @State private var showingSDKSettings = false
    @State private var showingSystemImages = false

    var body: some View {
        NavigationSplitView {
            InstanceListView(selection: $selection, showingCreateSheet: $showingCreateSheet)
        } detail: {
            if let id = selection, let instance = appState.store.instances.first(where: { $0.id == id }) {
                InstanceDetailView(instance: instance)
            } else if let error = appState.sdkError {
                ContentUnavailableView(
                    "未检测到 Android SDK",
                    systemImage: "exclamationmark.triangle",
                    description: Text(error)
                )
            } else {
                ContentUnavailableView("选择或创建一个模拟器实例", systemImage: "ipad.landscape")
            }
        }
        .toolbar {
            ToolbarItem {
                Button {
                    showingSystemImages = true
                } label: {
                    Label("系统镜像管理", systemImage: "arrow.down.circle")
                }
            }
            ToolbarItem {
                Button {
                    showingSDKSettings = true
                } label: {
                    Label("SDK 设置", systemImage: "gearshape")
                }
            }
        }
        .sheet(isPresented: $showingCreateSheet) {
            CreateInstanceSheet()
        }
        .sheet(isPresented: $showingSDKSettings) {
            SDKSettingsView()
        }
        .sheet(isPresented: $showingSystemImages) {
            SystemImageManagerView()
        }
    }
}
