# TuTuMac

一个 macOS 原生的安卓模拟器管理壳程序,功能参考 MuMu 模拟器。

## 技术方案

**不是**从零实现虚拟化引擎——那相当于重做 MuMu 母公司数年的工程量。
本项目的做法是:用 **Google 官方 Android Emulator**(内部即 QEMU + macOS
`Hypervisor.framework` 加速,已原生支持 Apple Silicon)作为虚拟化底座,
在其上开发一个 **Swift + SwiftUI 原生 macOS 应用**,复刻 MuMu 的管理体验。

模拟器本身仍以独立窗口(Google 官方 UI)运行,TuTuMac 是围绕它的"控制中心"。

## 已实现功能

- **实例创建与生命周期管理**:新建/启动/停止/删除实例,底层对应一个 AVD
- **多开与实例克隆**:一键克隆现有实例(复制 AVD 磁盘镜像与配置)
- **APK 拖拽安装**:把 `.apk` 文件拖到实例详情页,自动 `adb install -r`
- **性能设置面板**:内存 / CPU 核心数 / 分辨率 / 密度 / GPU 加速模式(写入 AVD `config.ini`)
- **截图与录屏**:`adb screencap` / `adb screenrecord`,输出到「图片/视频」目录下的 `TuTuMac` 文件夹
- **按键映射**:可视化编辑器(点击预览屏幕选取触控点 + 按键绑定),运行时通过全局按键监听
  (`CGEventTap`)转换为 `adb shell input tap/swipe/keyevent`
- **Root 管理**:实例详情页 → 「Root 管理」,可执行 `adb root` / `adb unroot` / `adb remount`
  并查询当前 adbd 是否以 root 身份运行(注意 Google Play 系统镜像通常不支持 root)
- **电脑键盘输入**:性能设置面板里的「启用电脑键盘直接输入」开关(写入 AVD 的 `hw.keyboard`);
  新建实例时默认就会自动开启。如果之前用命令行 `avdmanager` 建的 AVD 觉得键盘输不进去,就是因为这个开关默认是关的。
- **共享文件夹**:实例详情页 → 「共享文件夹」,电脑侧目录在
  `~/Library/Application Support/TuTuMac/SharedFolders/<AVD名>/`,可直接在 Finder 中打开;
  点「推送到手机」把该目录内容同步到设备的 `/sdcard/TuTuMac`(在手机「文件」App的
  内部存储下可见),点「从手机拉取」反向同步。注意这不是实时挂载,而是手动触发的一次性
  全量同步(逐项推送/拉取,避免 `adb push/pull` 整目录时多套一层子目录的问题)。

## 目录结构

```
mumu/
  Package.swift
  Sources/TuTuMac/
    TuTuMacApp.swift        # 应用入口
    AppState.swift          # 全局状态:SDK 探测、AVD 列表、各 Manager 单例
    Core/                   # 与命令行工具交互的核心层
      ShellRunner.swift      # Process 封装
      SDKLocator.swift       # 自动探测 Android SDK 路径
      ConfigINI.swift        # AVD config.ini 读写
      ADBService.swift       # adb 操作(安装/输入/截图/录屏)
      AVDManager.swift       # AVD 增删改查、克隆、性能设置写入
      EmulatorProcessManager.swift # emulator 子进程启动/停止/状态追踪
    Models/                 # 数据模型(实例、AVD、性能方案、按键映射)
    Store/InstanceStore.swift # 应用层数据持久化(JSON)
    Keymap/                 # 按键映射引擎与按键捕获视图
    Views/                  # SwiftUI 界面(含 RootManagementView.swift)
  Resources/Info.plist.template # 打包 .app 时使用的 Info.plist 模板
  Scripts/build_app.sh    # 打包为正式 .app 的脚本
```

## 环境要求

- Xcode / Swift toolchain(已用 Xcode 26.6 / Swift 6.3 验证)
- Android SDK,至少包含以下组件(用 `sdkmanager` 安装):
  ```
  sdkmanager "platform-tools" "emulator" \
    "system-images;android-34;google_apis_playstore;arm64-v8a"
  ```
- 应用会自动在以下位置探测 SDK:`$ANDROID_HOME` / `$ANDROID_SDK_ROOT` /
  `~/Library/Android/sdk` / `/opt/homebrew/share/android-commandlinetools` /
  `/usr/local/share/android-commandlinetools`。找不到时可在应用内「SDK 设置」
  手动指定根目录。

## 运行

```bash
cd mumu
swift build      # 编译
swift run TuTuMac # 编译并启动(GUI 窗口)
```

首次启动会自动把 `~/.android/avd` 下已有的 AVD 同步为"实例"列表。

## 故障排查

- **实例启动后一直"启动中…"最终变回"已停止"**:实例列表和详情页会出现红色
  ⚠️ 图标 / "启动失败"横幅,展示 emulator 日志尾部,可点击"在 Finder 中查看
  完整日志"(日志默认写在 `~/Library/Application Support/TuTuMac/Logs/<AVD名>.log`)。
- **最常见的失败原因:CPU 架构不匹配**。Apple Silicon(arm64)Mac 只能运行
  `arm64-v8a` 系统镜像,Intel Mac 只能运行 `x86_64` 镜像,选错会在日志里看到:
  ```
  FATAL | Avd's CPU Architecture 'x86_64' is not supported by the QEMU2 emulator on aarch64 host.
  ```
  「新建实例」界面现在会自动过滤掉与本机架构不兼容的系统镜像,避免再选错;
  如果已有的 AVD 是错误架构创建的,需要删除后用兼容架构的镜像重新创建,例如:
  ```bash
  avdmanager delete avd -n <名称>
  avdmanager create avd -n <名称> -k "system-images;android-34;google_apis_playstore;arm64-v8a" -d pixel_6 --force
  ```

## 打包为正式 .app

```bash
cd mumu
./Scripts/build_app.sh          # 默认 release 配置
open dist/TuTuMac.app           # 像正式 App 一样双击/打开
```

脚本会:

1. `swift build -c release` 编译产物
2. 组装出标准结构的 `dist/TuTuMac.app`(`Contents/MacOS` + `Contents/Info.plist`)
3. 用 ad-hoc 方式签名(`codesign --sign -`),使 Bundle Identifier
   (`com.tutumac.app`)保持稳定,「辅助功能」权限授权后不会因重新编译而失效

注意: ad-hoc 签名只适合本机自用,**不能**用于分发给其他 Mac(会被 Gatekeeper 拦截)。
如需分发,需要 Apple Developer 账号做正式签名 + 公证(notarization)。

## 已知限制 / 后续可做的事

- **窗口未嵌入**:模拟器本身仍以 Google 官方 Qt 窗口独立显示,TuTuMac 是外部
  控制面板,而非把模拟器画面渲染进自己的窗口(真正的画面嵌入需要逆向使用私有
  窗口合成接口,风险和复杂度都很高,暂不实现)。
- **按键映射的前台窗口匹配是"最佳努力"**:`emulator` 启动器有时会 exec/派生出
  真正承载 UI 的子进程(qemu),导致 `EmulatorProcessManager` 记录的 pid 与实际
  窗口 pid 不完全一致。如果映射不生效,请确认模拟器窗口确实处于最前台。
- **按键映射需要辅助功能权限**:`CGEventTap` 依赖「系统设置 → 隐私与安全性 →
  辅助功能」授权,应用内会提示并可一键跳转请求。
- **打包为正式 .app 仍无自定义图标**:`Scripts/build_app.sh` 已生成标准 `.app`
  bundle(含 `Info.plist`、ad-hoc 签名),但没有 `.icns` 图标资源,显示为系统默认
  图标;如需自定义图标,把 `.icns` 放进 `Contents/Resources` 并在 `Info.plist`
  加 `CFBundleIconFile` 即可。
- **未包含**:Google Play 登录/GApps 集成、多实例"一键同步操作"(对多个实例广播
  同一按键映射)。
