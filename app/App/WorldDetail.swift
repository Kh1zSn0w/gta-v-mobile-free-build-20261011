import Foundation

enum ViewDistance: Int, CaseIterable {
    case standard, extended, far
    var title: String { ["Standard", "Extended", "Far"][rawValue] }
    var lodExtra: Double { [0, 0.12, 0.25][rawValue] }
    var actorExtra: Double { [0, 0.05, 0.10][rawValue] }

    func apply(to options: [String]) -> [String] {
        options.map { option in
            for (prefix, extra) in [("-lodScale=", lodExtra), ("-pedLodBias=", actorExtra), ("-vehicleLodBias=", actorExtra)] {
                if option.hasPrefix(prefix), let value = Double(option.dropFirst(prefix.count)), extra > 0 {
                    return prefix + String(format: "%.2f", min(1, value + extra))
                }
            }
            return option
        }
    }
}

enum TextureClarity: Int, CaseIterable {
    case original = 0, clear = 4, high = 8
    var title: String { self == .original ? "Original" : "\(rawValue)×" }
}

