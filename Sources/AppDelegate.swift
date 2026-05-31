import Cocoa
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    let popover = NSPopover()
    let alarmManager = AlarmManager()
    var flightWindow: FlightWindow?
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Programmatically hide the Dock icon, running as a menu bar accessory application
        NSApp.setActivationPolicy(.accessory)
        
        // Setup popover containing the SwiftUI SettingsView
        popover.contentViewController = NSHostingController(rootView: SettingsView(manager: alarmManager))
        popover.behavior = .transient // Automatically closes when the user clicks elsewhere
        
        // Setup system status bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            // Use the native airplane SF Symbol
            if let image = NSImage(systemSymbolName: "airplane.circle.fill", accessibilityDescription: "飞机闹钟") {
                // Ensure it scales nicely to status bar height
                let config = NSImage.SymbolConfiguration(textStyle: .body, scale: .medium)
                button.image = image.withSymbolConfiguration(config)
            }
            button.action = #selector(togglePopover)
            button.target = self
        }
        
        // Handle alarm trigger
        alarmManager.onAlarmTrigger = { [weak self] reminderText, isImportant in
            self?.showFlightAnimation(text: reminderText, isImportant: isImportant)
        }
        
        // Handle active alarm dismissal from status bar menu
        alarmManager.onDismissActiveAlarm = { [weak self] in
            if let window = self?.flightWindow {
                window.dismiss()
            } else {
                self?.flightWindow = nil
            }
        }
    }
    
    @objc func togglePopover() {
        guard let button = statusItem?.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            // Show popover pointing to the menu bar button
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            // Make it the key window so text field and buttons respond immediately
            popover.contentViewController?.view.window?.makeKey()
        }
    }
    
    func showFlightAnimation(text: String, isImportant: Bool) {
        // Close any existing flight window to avoid overlaps
        if let existingWindow = flightWindow {
            existingWindow.close()
            flightWindow = nil
        }
        
        // Create new transparent window
        let window = FlightWindow(reminderText: text, isImportant: isImportant, style: alarmManager.selectedStyle, onFinished: { [weak self] in
            self?.flightWindow = nil
            self?.alarmManager.isAlarmFiring = false // Reset firing state
        })
        
        self.flightWindow = window
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless() // Keep it on top of everything
    }
}
