import SwiftUI

struct SDKSettingsView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var customPath: String = UserDefaults.standard.string(forKey: SDKLocator.userDefaultsKey) ?? ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Android SDK 设置").font(.title3.bold())
            if let sdk = appState.sdk {
                Text("当前 SDK 路径: \(sdk.sdkRoot.path)").font(.caption).foregroundStyle(.secondary)
            } else if let error = appState.sdkError {
                Text(error).font(.caption).foregroundStyle(.red)
            }
            TextField("自定义 SDK 根目录(留空则自动探测)", text: $customPath)
                .textFieldStyle(.roundedBorder)
            HStack {
                Spacer()
                Button("关闭") { dismiss() }
                Button("保存并重新检测") {
                    UserDefaults.standard.set(customPath, forKey: SDKLocator.userDefaultsKey)
                    appState.reloadSDK()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(width: 420)
    }
}
