import SwiftUI

enum SettingsActiveView: Equatable {
    case main
    case addEdit(Alarm?)
}

struct SettingsView: View {
    @ObservedObject var manager: AlarmManager
    @State private var activeView: SettingsActiveView = .main
    
    var body: some View {
        VStack(spacing: 0) {
            switch activeView {
            case .main:
                MainSettingsView(manager: manager, onAdd: {
                    activeView = .addEdit(nil)
                }, onEdit: { alarm in
                    activeView = .addEdit(alarm)
                })
            case .addEdit(let alarm):
                AddEditAlarmView(manager: manager, alarmToEdit: alarm, onCancel: {
                    activeView = .main
                }, onSave: {
                    activeView = .main
                })
            }
        }
        .frame(width: 320) // Balanced width to showcase list and settings
    }
}

// MARK: - Main Settings View
struct MainSettingsView: View {
    @ObservedObject var manager: AlarmManager
    var onAdd: () -> Void
    var onEdit: (Alarm) -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                Image(systemName: "airplane")
                    .foregroundColor(.blue)
                    .font(.system(size: 18, weight: .bold))
                Text("飞机飞行闹钟")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                Spacer()
            }
            .padding(.bottom, 2)
            
            // 0. Active Alarm Dismiss Button (Only shown when alarm is firing)
            if manager.isAlarmFiring {
                Button(action: {
                    manager.dismissActiveAlarm()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 13))
                        Text("关闭当前飞行的提醒")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.red)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .padding(.bottom, 4)
            }
            
            // 1. Quick Countdown Section
            VStack(alignment: .leading, spacing: 6) {
                Text("单次快速倒计时")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.secondary)
                
                if manager.isTimerActive {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("倒计时中: \(manager.timeRemainingFormatted)")
                                .font(.system(size: 13, weight: .bold, design: .monospaced))
                            Text(manager.reminderText)
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                        Spacer()
                        Button("取消") {
                            manager.cancelTimer()
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.red.opacity(0.15))
                        .foregroundColor(.red)
                        .cornerRadius(6)
                    }
                    .padding(8)
                    .background(Color.blue.opacity(0.06))
                    .cornerRadius(8)
                } else {
                    HStack(spacing: 8) {
                        TextField("提醒文案...", text: $manager.reminderText)
                            .textFieldStyle(.plain)
                            .padding(6)
                            .background(Color(nsColor: .controlBackgroundColor))
                            .cornerRadius(6)
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.gray.opacity(0.2), lineWidth: 1))
                            .font(.system(size: 11))
                        
                        Picker("", selection: $manager.selectedMinutes) {
                            ForEach(1..<60, id: \.self) { min in
                                Text("\(min) 分").tag(min)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 65)
                        
                        Button("启动") {
                            manager.startTimer()
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(6)
                        .font(.system(size: 11, weight: .bold))
                    }
                    
                    // Toggle for Quick Countdown Important status
                    Toggle("⚠️ 编队飞行 (重要事件)", isOn: $manager.isImportantQuick)
                        .toggleStyle(.checkbox)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }
            
            Divider()
            
            // 2. Recurring Alarms Section
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("周期性重复闹钟")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.secondary)
                    Spacer()
                    Button(action: onAdd) {
                        HStack(spacing: 2) {
                            Image(systemName: "plus")
                            Text("新增")
                        }
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.blue)
                    }
                    .buttonStyle(.plain)
                }
                
                if manager.alarms.isEmpty {
                    Text("暂无周期闹钟，点击右上角 + 新增")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .padding(.vertical, 16)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .background(Color(nsColor: .controlBackgroundColor).opacity(0.3))
                        .cornerRadius(8)
                } else {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 6) {
                            ForEach(manager.alarms) { alarm in
                                HStack(spacing: 6) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        HStack(spacing: 6) {
                                            Text(String(format: "%02d:%02d", alarm.hour, alarm.minute))
                                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                                .foregroundColor(alarm.isEnabled ? .primary : .secondary)
                                            
                                            if alarm.isImportant {
                                                Text("重要")
                                                    .font(.system(size: 8, weight: .bold))
                                                    .foregroundColor(.white)
                                                    .padding(.horizontal, 4)
                                                    .padding(.vertical, 1)
                                                    .background(Color.red)
                                                    .cornerRadius(4)
                                            }
                                            
                                            Text(alarm.title)
                                                .font(.system(size: 11))
                                                .foregroundColor(alarm.isEnabled ? .primary : .secondary)
                                                .lineLimit(1)
                                        }
                                        
                                        Text(formatWeekdays(alarm.weekdays))
                                            .font(.system(size: 9, weight: .semibold))
                                            .foregroundColor(.blue.opacity(alarm.isEnabled ? 0.8 : 0.4))
                                    }
                                    
                                    Spacer()
                                    
                                    Toggle("", isOn: Binding(
                                        get: { alarm.isEnabled },
                                        set: { _ in manager.toggleAlarmEnabled(id: alarm.id) }
                                    ))
                                    .toggleStyle(.switch)
                                    .scaleEffect(0.65)
                                    .frame(width: 30)
                                    
                                    Button(action: { onEdit(alarm) }) {
                                        Image(systemName: "pencil")
                                            .foregroundColor(.secondary)
                                            .font(.system(size: 10))
                                    }
                                    .buttonStyle(.plain)
                                    
                                    Button(action: { manager.deleteAlarm(id: alarm.id) }) {
                                        Image(systemName: "trash")
                                            .foregroundColor(.red.opacity(0.8))
                                            .font(.system(size: 10))
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 6)
                                .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
                                .cornerRadius(6)
                            }
                        }
                    }
                    .frame(maxHeight: 130)
                }
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("提醒模式")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.secondary)
                
                HStack(spacing: 5) {
                    ForEach([
                        (0, "普通飞过 ✈️"),
                        (1, "中间悬停 ⏸")
                    ], id: \.0) { item in
                        let val = item.0
                        let label = item.1
                        let isSelected = manager.alarmMode == val
                        
                        Button(action: {
                            manager.alarmMode = val
                            manager.saveSettings()
                        }) {
                            Text(label)
                                .font(.system(size: 11, weight: isSelected ? .bold : .regular))
                                .foregroundColor(isSelected ? .white : .primary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(isSelected ? Color.blue : Color.gray.opacity(0.15))
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Toggle(isOn: Binding(
                    get: { manager.isCalendarSyncEnabled },
                    set: { val in manager.toggleCalendarSync(enabled: val) }
                )) {
                    HStack(spacing: 3) {
                        Image(systemName: "calendar")
                            .foregroundColor(.blue)
                        Text("同步系统日历日程提醒")
                            .font(.system(size: 10, weight: .semibold))
                    }
                }
                .toggleStyle(.checkbox)
            }
            .padding(.top, 2)
            
            Divider()
            
            // 3. Footer / Settings
            HStack {
                // Autostart toggle
                Toggle(isOn: Binding(
                    get: { manager.launchAtLogin },
                    set: { _ in manager.toggleLaunchAtLogin() }
                )) {
                    Text("开机自启")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                .toggleStyle(.checkbox)
                
                Spacer()
                
                Button("测试预览") {
                    manager.triggerPreview()
                }
                .buttonStyle(.plain)
                .font(.system(size: 10))
                .foregroundColor(.blue)
                
                Text("|")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary.opacity(0.5))
                
                Button("退出应用") {
                    NSApp.terminate(nil)
                }
                .buttonStyle(.plain)
                .font(.system(size: 10))
                .foregroundColor(.red.opacity(0.8))
            }
        }
        .padding(12)
    }
    
    private func formatWeekdays(_ weekdays: Set<Int>) -> String {
        if weekdays.count == 7 { return "每天" }
        if weekdays == Set([2, 3, 4, 5, 6]) { return "工作日" }
        if weekdays == Set([7, 1]) { return "周末" }
        if weekdays.isEmpty { return "从不" }
        let dayMap = [2: "一", 3: "二", 4: "三", 5: "四", 6: "五", 7: "六", 1: "日"]
        let sorted = Array(weekdays).sorted { d1, d2 in
            let r1 = d1 == 1 ? 7 : d1 - 1
            let r2 = d2 == 1 ? 7 : d2 - 1
            return r1 < r2
        }
        return "每周" + sorted.compactMap { dayMap[$0] }.joined(separator: "、")
    }
}

// MARK: - Add/Edit Alarm View
struct AddEditAlarmView: View {
    @ObservedObject var manager: AlarmManager
    let alarmToEdit: Alarm?
    
    var onCancel: () -> Void
    var onSave: () -> Void
    
    @State private var title: String = ""
    @State private var hour: Int = 12
    @State private var minute: Int = 0
    @State private var weekdays: Set<Int> = [2, 3, 4, 5, 6] // Default to weekdays Mon-Fri
    @State private var isImportant: Bool = false
    
    var body: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                Text(alarmToEdit == nil ? "新建周期闹钟" : "编辑周期闹钟")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                Spacer()
            }
            
            // Text Input
            VStack(alignment: .leading, spacing: 4) {
                Text("提醒文字")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.secondary)
                TextField("如：下午茶时间到了...", text: $title)
                    .textFieldStyle(.plain)
                    .padding(8)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    )
            }
            
            // Time selection
            HStack {
                Text("时间")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.secondary)
                Spacer()
                HStack(spacing: 4) {
                    Picker("", selection: $hour) {
                        ForEach(0..<24, id: \.self) { hr in
                            Text(String(format: "%02d", hr)).tag(hr)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 55)
                    
                    Text(":")
                        .font(.system(size: 12, weight: .bold))
                    
                    Picker("", selection: $minute) {
                        ForEach(0..<60, id: \.self) { min in
                            Text(String(format: "%02d", min)).tag(min)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 55)
                }
            }
            
            // Toggle for Important Alarm
            Toggle("重要事件 (三机编队飞行)", isOn: $isImportant)
                .toggleStyle(.checkbox)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
            
            // Weekday selector
            VStack(alignment: .leading, spacing: 6) {
                Text("重复日期")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.secondary)
                
                WeekdaySelector(selectedDays: $weekdays)
            }
            .padding(.vertical, 4)
            
            // Action Buttons
            HStack(spacing: 8) {
                Button(action: onCancel) {
                    Text("取消")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(Color.gray.opacity(0.15))
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
                
                Button(action: save) {
                    Text("保存")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(Color.blue)
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .disabled(weekdays.isEmpty || title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(16)
        .onAppear {
            if let alarm = alarmToEdit {
                title = alarm.title
                hour = alarm.hour
                minute = alarm.minute
                weekdays = alarm.weekdays
                isImportant = alarm.isImportant
            } else {
                // Pre-populate with typical setup matching user request example
                title = ""
                hour = 14
                minute = 55
                weekdays = [2, 3, 4, 5, 6] // Mon-Fri
                isImportant = false
            }
        }
    }
    
    private func save() {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if let existing = alarmToEdit {
            let updated = Alarm(id: existing.id, title: cleanTitle, hour: hour, minute: minute, weekdays: weekdays, isEnabled: existing.isEnabled, isImportant: isImportant)
            manager.updateAlarm(updated)
        } else {
            let newAlarm = Alarm(title: cleanTitle, hour: hour, minute: minute, weekdays: weekdays, isEnabled: true, isImportant: isImportant)
            manager.addAlarm(newAlarm)
        }
        onSave()
    }
}

// MARK: - Weekday Selector
struct WeekdaySelector: View {
    @Binding var selectedDays: Set<Int>
    
    // Ordered from Monday to Sunday: 2, 3, 4, 5, 6, 7, 1
    let days = [
        (2, "一"),
        (3, "二"),
        (4, "三"),
        (5, "四"),
        (6, "五"),
        (7, "六"),
        (1, "日")
    ]
    
    var body: some View {
        HStack(spacing: 6) {
            ForEach(days, id: \.0) { item in
                let val = item.0
                let label = item.1
                let isSelected = selectedDays.contains(val)
                
                Button(action: {
                    if isSelected {
                        selectedDays.remove(val)
                    } else {
                        selectedDays.insert(val)
                    }
                }) {
                    Text(label)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(isSelected ? .white : .primary)
                        .frame(width: 28, height: 28)
                        .background(
                            Circle()
                                .fill(isSelected ? Color.blue : Color.gray.opacity(0.15))
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }
}
