import Foundation
import EventKit

class CalendarManager: ObservableObject {
    static let shared = CalendarManager()
    let eventStore = EKEventStore()
    
    @Published var isAuthorized: Bool = false
    
    private init() {
        checkAuthorization()
    }
    
    func checkAuthorization() {
        let status = EKEventStore.authorizationStatus(for: .event)
        DispatchQueue.main.async {
            if #available(macOS 14.0, *) {
                // In macOS 14+, check for full access or authorized status
                self.isAuthorized = (status == .fullAccess || status == .authorized)
            } else {
                self.isAuthorized = (status == .authorized)
            }
        }
    }
    
    func requestAccess(completion: @escaping (Bool, Error?) -> Void) {
        if #available(macOS 14.0, *) {
            eventStore.requestFullAccessToEvents { [weak self] granted, error in
                self?.checkAuthorization()
                completion(granted, error)
            }
        } else {
            eventStore.requestAccess(to: .event) { [weak self] granted, error in
                self?.checkAuthorization()
                completion(granted, error)
            }
        }
    }
    
    func fetchTodayEvents() -> [EKEvent] {
        checkAuthorization()
        guard isAuthorized else { return [] }
        
        let calendar = Calendar.current
        let now = Date()
        
        let start = calendar.startOfDay(for: now)
        let end = calendar.date(byAdding: .day, value: 1, to: start)!
        
        let predicate = eventStore.predicateForEvents(withStart: start, end: end, calendars: nil)
        let events = eventStore.events(matching: predicate)
        
        // Filter out all-day events and events that started in the past
        return events.filter { !$0.isAllDay && $0.startDate > now }
            .sorted { $0.startDate < $1.startDate }
    }
}
