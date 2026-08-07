import SwiftUI

struct CreateInstanceSheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var selectedImage: String = ""
    @State private var deviceProfile: String = "pixel_6"
    @State private var systemImages: [String] = []
    @State private var errorMessage: String?
    @State private var isCreating = false
    @State private var showingSystemImageManager = false

    private let deviceProfiles = ["pixel_5", "pixel_6", "pixel_7", "pixel_tablet", "Nexus 5"]

    /// 与本机 CPU 架构兼容、能被 emulator 加速运行的镜像。
    private var compatibleImages: [String] {
        systemImages.filter { $0.hasSuffix(";" + HostArchitecture.compatibleABI) }
    }

    /// 与本机架构不匹配、选它会导致 emulator 启动时直接 FATAL 退出的镜像。
    private var incompatibleImages: [String] {
        systemImages.filter { !$0.hasSuffix(";" + HostArchitecture.compatibleABI) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("新建模拟器实例").font(.title2.bold())

            TextField("实例名称", text: $name)
                .textFieldStyle(.roundedBorder)

            Picker("系统镜像", selection: $selectedImage) {
                ForEach(compatibleImages, id: \.self) { Text($0).tag($0) }
            }

            Picker("设备型号", selection: $deviceProfile) {
                ForEach(deviceProfiles, id: \.self) { Text($0).tag($0) }
            }

            if compatibleImages.isEmpty {
                Text("未检测到与本机架构(\(HostArchitecture.compatibleABI))兼容的已安装系统镜像。")
                    .font(.caption)
                    .foregroundStyle(.orange)
                Button("去下载系统镜像…") { showingSystemImageManager = true }
                    .font(.caption)
            } else {
                Button("管理/下载更多系统镜像…") { showingSystemImageManager = true }
                    .font(.caption)
            }

            if !incompatibleImages.isEmpty {
                Text("以下镜像与本机 CPU 架构不匹配、无法加速运行,已隐藏: \(incompatibleImages.joined(separator: "、"))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let errorMessage {
                Text(errorMessage).foregroundStyle(.red).font(.caption)
            }

            HStack {
                Spacer()
                Button("取消") { dismiss() }
                Button("创建") { create() }
                    .disabled(name.isEmpty || selectedImage.isEmpty || isCreating)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(width: 460)
        .onAppear(perform: loadImages)
        .sheet(isPresented: $showingSystemImageManager, onDismiss: loadImages) {
            SystemImageManagerView()
        }
    }

    private func loadImages() {
        if let images = try? appState.avdManager?.installedSystemImages() {
            systemImages = images
        }
        selectedImage = compatibleImages.first ?? ""
    }

    private func create() {
        guard let avdManager = appState.avdManager else { return }
        isCreating = true
        let name = name
        let selectedImage = selectedImage
        let deviceProfile = deviceProfile
        Task.detached(priority: .userInitiated) {
            do {
                try avdManager.createAVD(name: name, systemImage: selectedImage, device: deviceProfile)
                await MainActor.run {
                    appState.refreshAVDs()
                    appState.store.upsert(EmulatorInstance(displayName: name, avdName: name))
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isCreating = false
                }
            }
        }
    }
}
