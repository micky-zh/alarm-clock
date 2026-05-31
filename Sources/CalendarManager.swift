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
}
