import Foundation

/// 读写 Android AVD 使用的简单 key=value 配置文件(如 config.ini / <name>.ini)。
struct ConfigINI {
    private(set) var order: [String] = []
    private var values: [String: String] = [:]

    init(contentsOf url: URL) throws {
        let text = try String(contentsOf: url, encoding: .utf8)
        for line in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, !trimmed.hasPrefix("#"), let eq = trimmed.firstIndex(of: "=") else { continue }
            let key = String(trimmed[trimmed.startIndex..<eq]).trimmingCharacters(in: .whitespaces)
            let value = String(trimmed[trimmed.index(after: eq)...]).trimmingCharacters(in: .whitespaces)
            if values[key] == nil { order.append(key) }
            values[key] = value
        }
    }

    subscript(key: String) -> String? {
        get { values[key] }
        set {
            if values[key] == nil, let newValue {
                order.append(key)
                values[key] = newValue
            } else {
                values[key] = newValue
            }
        }
    }

    func write(to url: URL) throws {
        let lines = order.compactMap { key in values[key].map { "\(key)=\($0)" } }
        let text = lines.joined(separator: "\n") + "\n"
        try text.write(to: url, atomically: true, encoding: .utf8)
    }
}
