import Foundation

@MainActor
final class PreferencesStore {
    static let shared = PreferencesStore()

    private let defaults: UserDefaults
    private let storageKey = "class-assistant-ui-style"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> UIStyleSettings {
        guard let data = defaults.data(forKey: storageKey),
              let settings = try? JSONDecoder().decode(UIStyleSettings.self, from: data) else {
            return .default
        }

        return settings
    }

    func save(_ settings: UIStyleSettings) {
        guard let data = try? JSONEncoder().encode(settings) else {
            return
        }

        defaults.set(data, forKey: storageKey)
    }
}
