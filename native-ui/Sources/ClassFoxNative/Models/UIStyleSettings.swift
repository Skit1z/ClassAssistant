import Foundation

enum BackgroundPreset: String, CaseIterable, Codable, Identifiable {
    case ocean
    case sunset
    case forest
    case slate

    var id: String {
        rawValue
    }

    var displayName: String {
        rawValue.capitalized
    }
}

struct UIStyleSettings: Codable, Equatable {
    var version: Int = 2
    var backgroundPreset: BackgroundPreset = .ocean
    var windowRadius: Double = 10
    var shellOpacity: Double = 0.9
    var fontScale: Double = 1

    static let `default` = UIStyleSettings()
}
