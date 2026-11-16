import Foundation

enum BackgroundRefreshPolicy {
    static let key = "backgroundRefreshSyncEnabled"

    static func isEnabled(_ defaults: UserDefaults = .standard) -> Bool {
        (defaults.object(forKey: key) as? Bool) ?? true
    }
}
