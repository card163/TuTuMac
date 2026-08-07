import Foundation

enum ShellError: Error, LocalizedError {
    case launchFailed(String)
    case nonZeroExit(Int32, String)

    var errorDescription: String? {
        switch self {
        case .launchFailed(let reason): return "无法启动进程: \(reason)"
        case .nonZeroExit(let code, let output): return "命令退出码 \(code): \(output)"
        }
    }
}

/// 封装对外部命令行工具(adb / emulator / avdmanager / sdkmanager)的调用。
enum ShellRunner {
    /// 同步运行一个命令并返回标准输出,非零退出码会抛出错误。
    @discardableResult
    static func run(_ executable: String, _ arguments: [String], currentDirectory: URL? = nil) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        if let currentDirectory {
            process.currentDirectoryURL = currentDirectory
        }
        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe

        do {
            try process.run()
        } catch {
            throw ShellError.launchFailed(error.localizedDescription)
        }

        // 并发读取 stdout/stderr,避免管道缓冲区写满导致子进程和本进程互相阻塞。
        var outData = Data()
        var errData = Data()
        let group = DispatchGroup()
        group.enter()
        DispatchQueue.global(qos: .utility).async {
            outData = outPipe.fileHandleForReading.readDataToEndOfFile()
            group.leave()
        }
        group.enter()
        DispatchQueue.global(qos: .utility).async {
            errData = errPipe.fileHandleForReading.readDataToEndOfFile()
            group.leave()
        }
        process.waitUntilExit()
        group.wait()

        let output = String(data: outData, encoding: .utf8) ?? ""
        let errOutput = String(data: errData, encoding: .utf8) ?? ""
        if process.terminationStatus != 0 {
            throw ShellError.nonZeroExit(process.terminationStatus, errOutput.isEmpty ? output : errOutput)
        }
        return output
    }

    /// 运行一个可能会弹出"Accept? (y/N)"许可确认交互的命令(典型场景: sdkmanager 下载
    /// 未接受过许可的系统镜像),提前往 stdin 里灌入一批 "y",相当于 `yes | 命令`。
    @discardableResult
    static func runAutoAcceptingPrompts(_ executable: String, _ arguments: [String]) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        let inPipe = Pipe()
        let outPipe = Pipe()
        process.standardInput = inPipe
        process.standardOutput = outPipe
        process.standardError = outPipe

        do {
            try process.run()
        } catch {
            throw ShellError.launchFailed(error.localizedDescription)
        }

        // sdkmanager 最多会为几种不同的许可证分别弹一次确认,20 次 "y" 足够覆盖。
        if let answers = String(repeating: "y\n", count: 20).data(using: .utf8) {
            inPipe.fileHandleForWriting.write(answers)
        }
        try? inPipe.fileHandleForWriting.close()

        var outData = Data()
        let group = DispatchGroup()
        group.enter()
        DispatchQueue.global(qos: .utility).async {
            outData = outPipe.fileHandleForReading.readDataToEndOfFile()
            group.leave()
        }
        process.waitUntilExit()
        group.wait()

        let output = String(data: outData, encoding: .utf8) ?? ""
        if process.terminationStatus != 0 {
            throw ShellError.nonZeroExit(process.terminationStatus, output)
        }
        return output
    }

    /// 启动一个长期运行的后台进程(如 emulator),返回 Process 供调用方持有和终止。
    static func spawn(_ executable: String, _ arguments: [String], currentDirectory: URL? = nil) throws -> Process {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        if let currentDirectory {
            process.currentDirectoryURL = currentDirectory
        }
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        return process
    }

    /// 启动一个长期运行的后台进程,并把 stdout/stderr 都写入日志文件,便于排查启动失败原因。
    static func spawnWithLog(_ executable: String, _ arguments: [String], logFileURL: URL) throws -> Process {
        FileManager.default.createFile(atPath: logFileURL.path, contents: nil)
        let handle = try FileHandle(forWritingTo: logFileURL)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = handle
        process.standardError = handle
        try process.run()
        try? handle.close() // 子进程已拿到自己的 fd 副本,父进程这份可以立即关闭
        return process
    }

    /// 读取日志文件末尾若干行,用于在启动失败时展示诊断信息。
    static func tail(of url: URL, lines: Int) -> String? {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        let allLines = text.split(separator: "\n", omittingEmptySubsequences: true)
        guard !allLines.isEmpty else { return nil }
        return allLines.suffix(lines).joined(separator: "\n")
    }
}
