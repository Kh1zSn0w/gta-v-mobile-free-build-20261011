import Foundation
import Metal
import UIKit
import os

/// One detail the player can set apart from the preset (GTA-84): an engine option and its choices.
struct GraphicsDetail {
    let option: String
    let title: String
    let values: [String]
    let names: [String]

    static let all: [GraphicsDetail] = {
        let levels = [AppLanguage.choose("Low"), AppLanguage.choose("High"), AppLanguage.choose("Very high")]
        let percent = ["0", "0.2", "0.4", "0.6", "0.8", "1"]
        return [
            GraphicsDetail(option: "textureQuality", title: AppLanguage.choose("Textures"), values: ["0", "1", "2"], names: levels),
            GraphicsDetail(option: "shadowQuality", title: AppLanguage.choose("Shadows"), values: ["-1", "0", "1", "2"], names: [AppLanguage.choose("Off")] + levels),
            GraphicsDetail(option: "reflectionQuality", title: AppLanguage.choose("Reflections"), values: ["0", "1", "2"], names: levels),
            GraphicsDetail(option: "lodScale", title: AppLanguage.choose("Draw distance"), values: percent, names: percent.map { "\(Int((Double($0) ?? 0) * 100))%" }),
            GraphicsDetail(option: "grassQuality", title: AppLanguage.choose("Grass"), values: ["0", "1", "2"], names: levels),
            GraphicsDetail(option: "cityDensity", title: AppLanguage.choose("Traffic and people"), values: percent, names: percent.map { "\(Int((Double($0) ?? 0) * 100))%" }),
        ]
    }()

    /// The preset's own value for this detail.
    func presetValue(_ preset: GraphicsPreset) -> String {
        preset.engineOptions.first { $0.hasPrefix("-\(option)=") }.map { String($0.dropFirst(option.count + 2)) } ?? values[0]
    }
    func name(of value: String) -> String { values.firstIndex(of: value).map { names[$0] } ?? value }
}

/// What this device can afford, measured before the engine starts.
struct DeviceTier {
    let memoryLimitMB: Int
    let physicalMemoryMB: Int
    let model: String
    let supportsBCTextures: Bool

    /// BC textures sampled as they are; the property exists from iOS 16.4 (before that: decoded).
    static func readsBC(_ device: MTLDevice?) -> Bool {
        guard let device else { return false }
        if #available(iOS 16.4, *) { return device.supportsBCTextureCompression }
        return false
    }

    static func probe() -> DeviceTier {
        var info = utsname(); uname(&info)
        let model = withUnsafeBytes(of: &info.machine) { String(decoding: $0.prefix { $0 != 0 }, as: UTF8.self) }
        let device = MTLCreateSystemDefaultDevice()
        return DeviceTier(memoryLimitMB: Self.processMemoryLimitMB(),
                          physicalMemoryMB: Int(ProcessInfo.processInfo.physicalMemory / 1_048_576),
                          model: model,
                          supportsBCTextures: Self.readsBC(device))
    }

    /// Jetsam limit = memory still available + what the app already uses.
    private static func processMemoryLimitMB() -> Int {
        #if targetEnvironment(simulator)
        // Model the target phone (iPhone 13 Pro Max) unless told otherwise.
        return Int(ProcessInfo.processInfo.environment["PG_SIM_MEMORY_LIMIT_MB"] ?? "") ?? 4096
        #else
        var vm = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &vm) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count) }
        }
        let footprint = result == KERN_SUCCESS ? Int(vm.phys_footprint) : 0
        return (Int(os_proc_available_memory()) + footprint) / 1_048_576
        #endif
    }

    /// The Metal renderer needs about 700 MB less than the old renderer did: a 6 GB phone on a
    /// free Apple ID (about 3 GB limit) runs Battery with room to spare.
    var recommended: GraphicsPreset {
        GraphicsPreset.liteAvailable && memoryLimitMB < 2600 ? .lite : memoryLimitMB < 3400 ? .battery : memoryLimitMB < 4600 ? .performance : memoryLimitMB < 6000 ? .balanced : memoryLimitMB < 8000 ? .quality : .ultra
    }
    /// Every preset can be chosen; those above the recommended one show a warning.
    var allowed: [GraphicsPreset] { GraphicsPreset.available }
    /// Presets shown with a warning because they may run out of memory or heat up.
    func risky(_ preset: GraphicsPreset) -> Bool { preset.rawValue > recommended.rawValue }
    /// For the log (kept in English).
    var summary: String { "\(model) · \(physicalMemoryMB / 1024) GB · app limit \(memoryLimitMB) MB\(supportsBCTextures ? " · BC textures" : "")" }
    /// The same line for Settings, in the app's language.
    var displaySummary: String {
        AppLanguage.interpolate(AppLanguage.choose("{arg0} · {arg1} GB · app limit {arg2} MB"), [model, String(physicalMemoryMB / 1024), String(memoryLimitMB)])
            + (supportsBCTextures ? " · " + AppLanguage.choose("BC textures") : "")
    }

    /// Whether this install was signed with the increased memory limit (Apple grants it per
    /// signature, so a sideloading tool can drop it). nil when it can't be read.
    static let increasedMemoryGranted: Bool? = entitlement("com.apple.developer.kernel.increased-memory-limit")
    /// For Settings and the log: is the extra memory actually in effect?
    var increasedMemoryStatus: String {
        switch Self.increasedMemoryGranted {
        case true?: return AppLanguage.interpolate(AppLanguage.choose("Extra memory: on. This install has the increased memory limit, so the game may use up to {arg0} MB."), ["\(memoryLimitMB)"])
        case false?: return AppLanguage.interpolate(AppLanguage.choose("Extra memory: off. This install was signed without the increased memory limit, so the game gets the normal {arg0} MB. Install the \"unlimited\" build with a paid developer account, or GetMoreRam on a free one, for more."), ["\(memoryLimitMB)"])
        case nil: return AppLanguage.interpolate(AppLanguage.choose("Extra memory: unknown. The game may use up to {arg0} MB."), ["\(memoryLimitMB)"])
        }
    }

    /// Reads a boolean entitlement of this app (SecTask is not public on iOS, so it is looked up at run time).
    private static func entitlement(_ key: String) -> Bool? {
        #if targetEnvironment(simulator)
        return nil
        #else
        typealias Create = @convention(c) (CFAllocator?) -> Unmanaged<AnyObject>?
        typealias Copy = @convention(c) (AnyObject, CFString, UnsafeMutablePointer<Unmanaged<CFError>?>?) -> Unmanaged<AnyObject>?
        guard let handle = dlopen("/System/Library/Frameworks/Security.framework/Security", RTLD_LAZY),
              let create = dlsym(handle, "SecTaskCreateFromSelf"), let copy = dlsym(handle, "SecTaskCopyValueForEntitlement"),
              let task = unsafeBitCast(create, to: Create.self)(nil)?.takeRetainedValue() else { return nil }
        let value = unsafeBitCast(copy, to: Copy.self)(task, key as CFString, nil)?.takeRetainedValue()
        return (value as? Bool) ?? false
        #endif
    }
}

enum GraphicsConfiguration {
    /// The screen's height in pixels (the "Native" resolution).
    static var nativeHeight: Int {
        let screen = UIScreen.main
        return Int(min(screen.nativeBounds.width, screen.nativeBounds.height))
    }
    /// Resolutions offered in Settings, besides "Auto" (the detail preset's own).
    static var resolutionChoices: [Int] { [360, 432, 540, 720, 900, 1080].filter { $0 < nativeHeight } + [nativeHeight] }
    /// Width/height to render at: the chosen height (or the preset's), shaped like the screen so the
    /// picture is not stretched.
    static func size(for preset: GraphicsPreset, renderHeight: Int, screen: CGSize, matchScreenShape: Bool) -> (Int, Int) {
        let aspect = matchScreenShape && screen.height > 0 ? max(screen.width, screen.height) / min(screen.width, screen.height) : 16.0 / 9.0
        var height = Double(renderHeight > 0 ? renderHeight : preset.height)
        height = min(max(height, 360), Double(max(nativeHeight, 720)))
        let width = min(height * aspect, 3840)
        func even(_ value: Double) -> Int { Int(value.rounded()) & ~1 }
        return (even(width), even(height))
    }

    /// Pass the chosen settings to the engine. Call before PGStartEngine.
    static func apply(_ settings: GameSettings, screen: CGSize, tv: Bool = false) -> String {
        let preset = settings.graphicsPreset
        let (width, height) = size(for: preset, renderHeight: preset == .lite ? 360 : settings.renderHeight, screen: screen, matchScreenShape: tv || settings.matchScreenShape)
        // The player's own details replace the preset's (GTA-84).
        let overrides = preset == .lite ? [:] : settings.graphicsOverrides
        let resourcePreset: GraphicsPreset = preset == .extreme && settings.tier.memoryLimitMB < 5000 ? .balanced : preset
        var baseOptions = resourcePreset.engineOptions
        if settings.sharperWorld && [.balanced, .quality, .ultra, .extreme].contains(resourcePreset) {
            let levels: [GraphicsPreset: (String, String)] = [.balanced: ("0.30", "0.10"), .quality: ("0.50", "0.30"), .ultra: ("0.70", "0.50"), .extreme: ("0.70", "0.40")]
            if let level = levels[resourcePreset] {
                baseOptions = baseOptions.map { option in
                    if option.hasPrefix("-lodScale=") { return "-lodScale=" + level.0 }
                    if option.hasPrefix("-pedLodBias=") { return "-pedLodBias=" + level.1 }
                    if option.hasPrefix("-vehicleLodBias=") { return "-vehicleLodBias=" + level.1 }
                    return option
                }
            }
        }
        if preset != .lite { baseOptions = settings.viewDistance.apply(to: baseOptions) }
        let options = baseOptions.map { option -> String in
            let name = String(option.dropFirst().prefix { $0 != "=" })
            return overrides[name].map { "-\(name)=\($0)" } ?? option
        }
        let own = GraphicsDetail.all.compactMap { detail in overrides[detail.option].map { "\(detail.option) \($0)" } }
        // The engine and renderer read PG_LITE when they start, after this. The Lite build always sets it.
        if preset == .lite { setenv("PG_LITE", "1", 1) } else if !Theme.isLite { unsetenv("PG_LITE") }
        GameSettings.applyExperimentalSwitches()
        PGSetTextureClarity(preset == .lite ? 0 : UInt32(settings.textureClarity.rawValue))
        PGSetMemoryCap(Int32(settings.memoryCapMB > 0 ? settings.memoryCapMB : preset == .extreme ? 8192 : 0))
        PGSetSharperUpscaling(preset != .lite && settings.sharperUpscaling ? 1 : 0)
        var pointers = options.map { strdup($0) }
        defer { pointers.forEach { free($0) } }
        pointers.withUnsafeMutableBufferPointer { buffer in
            buffer.baseAddress!.withMemoryRebound(to: UnsafePointer<CChar>?.self, capacity: buffer.count) {
                PGConfigureEngine($0, UInt32(buffer.count), Int32(width), Int32(height), settings.frameRateCap == 0 ? 0 : settings.frameRateCap == 60 ? 1 : 2)
            }
        }
        return "\(preset.title) \(width)×\(height) at \(GameSettings.frameRateTitle(settings.frameRateCap))" + (own.isEmpty ? "" : ", own settings: " + own.joined(separator: ", "))
    }
}
