import Cocoa
import Foundation

// Enforce single instance using a lock file
let lockPath = NSTemporaryDirectory() + "com.airplane.alarm.lock"
let fileManager = FileManager.default

if fileManager.fileExists(atPath: lockPath) {
    if let data = try? Data(contentsOf: URL(fileURLWithPath: lockPath)),
       let pidString = String(data: data, encoding: .utf8),
       let pid = Int32(pidString.trimmingCharacters(in: .whitespacesAndNewlines)),
       kill(pid, 0) == 0 {
        print("⚠️ 提示：飞机闹钟已经在运行中 (PID: \(pid))。")
        print("请先在顶部状态栏点击小飞机并选择『退出应用』，或者在终端运行：killall airplane")
        exit(0)
    }
}

// Write current PID to the lock file
try? String(ProcessInfo.processInfo.processIdentifier).write(toFile: lockPath, atomically: true, encoding: .utf8)

// Register clean up on termination
atexit {
    let lockPath = NSTemporaryDirectory() + "com.airplane.alarm.lock"
    try? FileManager.default.removeItem(atPath: lockPath)
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
