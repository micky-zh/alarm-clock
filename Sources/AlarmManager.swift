import Foundation
import Combine

// MARK: - Alarm Model
struct Alarm: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var title: String
    var hour: Int
    var minute: Int
    var weekdays: Set<Int> // 1 = Sunday, 2 = Monday, 3 = Tuesday, ...
    var isEnabled: Bool = true
    var isImportant: Bool = false
}

// MARK: - AlarmManager
class AlarmManager: ObservableObject {
    @Published var reminderText: String = "该休息一下啦，起来活动活动吧！"
    @Published var selectedMinutes: Int = 5
    @Published var selectedSeconds: Int = 0
    
    @Published var isTimerActive: Bool = false
    @Published var timeRemaining: TimeInterval = 0
    
    @Published var alarms: [Alarm] = []
    @Published var launchAtLogin: Bool = false
    @Published var isImportantQuick: Bool = false
    @Published var selectedStyle: Int = 0
    @Published var alarmMode: Int = 0 // 0 = fly through, 1 = hover, 2 = loop
    @Published var isAlarmFiring: Bool = false
    @Published var isCalendarSyncEnabled: Bool = false
    
    private var timer: AnyCancellable?
    private var lastTriggeredTime: Date?
    
    var onAlarmTrigger: ((String, Bool, Int) -> Void)?
    var onDismissActiveAlarm: (() -> Void)?
    
    init() {
        loadSettings()
        startGlobalTimer()
    }
    
    func startGlobalTimer() {
        // Run a single global timer ticking every 1.0 second
        timer = Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.tick()
            }
    }
    
    private func tick() {
        // 1. Tick the quick countdown timer
        if isTimerActive {
            if timeRemaining > 1 {
                timeRemaining -= 1
            } else {
                timeRemaining = 0
                isTimerActive = false
                triggerAlarm(text: reminderText.isEmpty ? "提醒时间到！" : reminderText, isImportant: isImportantQuick, mode: alarmMode)
            }
        }
        
        // 2. Check recurring alarms
        checkRecurringAlarms()
    }
    
    // Countdown Timer Controls
    func startTimer() {
        let totalSeconds = TimeInterval(selectedMinutes * 60 + selectedSeconds)
        guard totalSeconds > 0 else { return }
        
        timeRemaining = totalSeconds
        isTimerActive = true
    }
    
    func cancelTimer() {
        isTimerActive = false
        timeRemaining = 0
    }
    
    func triggerAlarm(text: String, isImportant: Bool, mode: Int) {
        isAlarmFiring = true
        DispatchQueue.main.async {
            self.onAlarmTrigger?(text, isImportant, mode)
        }
    }
    
    func dismissActiveAlarm() {
        isAlarmFiring = false
        onDismissActiveAlarm?()
    }
    
    func triggerPreview() {
        let text = reminderText.isEmpty ? "这是一条测试预览提醒飞机拉幅横幅！" : reminderText
        triggerAlarm(text: text, isImportant: isImportantQuick, mode: alarmMode)
    }
    
    var timeRemainingFormatted: String {
        let mins = Int(timeRemaining) / 60
        let secs = Int(timeRemaining) % 60
        return String(format: "%02d:%02d", mins, secs)
    }
    
    // MARK: - Recurring Alarms CRUD
    
    func addAlarm(_ alarm: Alarm) {
        alarms.append(alarm)
        saveSettings()
    }
    
    func updateAlarm(_ alarm: Alarm) {
        if let index = alarms.firstIndex(where: { $0.id == alarm.id }) {
            alarms[index] = alarm
            saveSettings()
        }
    }
    
    func deleteAlarm(id: UUID) {
        alarms.removeAll(where: { $0.id == id })
        saveSettings()
    }
    
    func toggleAlarmEnabled(id: UUID) {
        if let index = alarms.firstIndex(where: { $0.id == id }) {
            alarms[index].isEnabled.toggle()
            saveSettings()
        }
    }
    
    private func checkRecurringAlarms() {
        let now = Date()
        let calendar = Calendar.current
        let components = calendar.dateComponents([.weekday, .hour, .minute], from: now)
        guard let currentWeekday = components.weekday,
              let currentHour = components.hour,
              let currentMinute = components.minute else { return }
        
        // Prevent double triggers within the same minute
        if let lastTrigger = lastTriggeredTime {
            let lastComponents = calendar.dateComponents([.weekday, .hour, .minute], from: lastTrigger)
            if lastComponents.weekday == currentWeekday &&
               lastComponents.hour == currentHour &&
               lastComponents.minute == currentMinute {
                return
            }
        }
        
        for alarm in alarms where alarm.isEnabled {
            if alarm.hour == currentHour &&
               alarm.minute == currentMinute &&
               alarm.weekdays.contains(currentWeekday) {
                lastTriggeredTime = now
                triggerAlarm(text: alarm.title.isEmpty ? "提醒时间到！" : alarm.title, isImportant: alarm.isImportant, mode: alarmMode)
                break // Trigger only one alarm at a time
            }
        }
    }
    
    // MARK: - Persistence & LaunchAgent
    
    private let alarmsKey = "com.airplane.alarms"
    private let launchKey = "com.airplane.launchAtLogin"
    private let styleKey = "com.airplane.selectedStyle"
    private let modeKey = "com.airplane.alarmMode"
    private let calendarSyncKey = "com.airplane.calendarSyncEnabled"
    
    func toggleLaunchAtLogin() {
        launchAtLogin.toggle()
        saveSettings()
        updateLaunchAgent()
    }
    
    func toggleCalendarSync(enabled: Bool) {
        if enabled {
            CalendarManager.shared.requestAccess { [weak self] granted, error in
                DispatchQueue.main.async {
                    if granted {
                        self?.isCalendarSyncEnabled = true
                    } else {
                        self?.isCalendarSyncEnabled = false
                    }
                    self?.saveSettings()
                }
            }
        } else {
            self.isCalendarSyncEnabled = false
            saveSettings()
        }
    }
    
    func saveSettings() {
        if let encoded = try? JSONEncoder().encode(alarms) {
            UserDefaults.standard.set(encoded, forKey: alarmsKey)
        }
        UserDefaults.standard.set(launchAtLogin, forKey: launchKey)
        UserDefaults.standard.set(selectedStyle, forKey: styleKey)
        UserDefaults.standard.set(alarmMode, forKey: modeKey)
        UserDefaults.standard.set(isCalendarSyncEnabled, forKey: calendarSyncKey)
    }
    
    private func loadSettings() {
        if let data = UserDefaults.standard.data(forKey: alarmsKey),
           let decoded = try? JSONDecoder().decode([Alarm].self, from: data) {
            self.alarms = decoded
        }
        self.launchAtLogin = UserDefaults.standard.bool(forKey: launchKey)
        self.selectedStyle = 0
        let loadedMode = UserDefaults.standard.integer(forKey: modeKey)
        self.alarmMode = (loadedMode == 0 || loadedMode == 1) ? loadedMode : 0
        self.isCalendarSyncEnabled = UserDefaults.standard.bool(forKey: calendarSyncKey)
    }
    
    private var launchAgentPlistPath: URL {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        return homeDir.appendingPathComponent("Library/LaunchAgents/com.airplane.alarm.plist")
    }
    
    private func updateLaunchAgent() {
        let path = launchAgentPlistPath
        if launchAtLogin {
            // Find absolute path of currently running executable
            let executablePath = URL(fileURLWithPath: CommandLine.arguments[0]).path
            let plistContent = """
            <?xml version="1.0" encoding="UTF-8"?>
            <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
            <plist version="1.0">
            <dict>
                <key>Label</key>
                <string>com.airplane.alarm</string>
                <key>ProgramArguments</key>
                <array>
                    <string>\(executablePath)</string>
                </array>
                <key>RunAtLoad</key>
                <true/>
            </dict>
            </plist>
            """
            
            let agentsDir = path.deletingLastPathComponent()
            try? FileManager.default.createDirectory(at: agentsDir, withIntermediateDirectories: true, attributes: nil)
            try? plistContent.write(to: path, atomically: true, encoding: .utf8)
        } else {
            try? FileManager.default.removeItem(at: path)
        }
    }
}
