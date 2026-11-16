import Foundation

let suite = "dev.freeband.tests.background-refresh." + UUID().uuidString
let defaults = UserDefaults(suiteName: suite)!
defer { defaults.removePersistentDomain(forName: suite) }
precondition(BackgroundRefreshPolicy.isEnabled(defaults), "existing installs must default to enabled")
defaults.set(false, forKey: BackgroundRefreshPolicy.key)
precondition(!BackgroundRefreshPolicy.isEnabled(defaults), "explicit opt-out must be respected")
defaults.set(true, forKey: BackgroundRefreshPolicy.key)
precondition(BackgroundRefreshPolicy.isEnabled(defaults), "re-enabling must work")
print("Background refresh policy checks passed")
