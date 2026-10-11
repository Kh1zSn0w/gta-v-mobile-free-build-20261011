import Foundation
import Metal
import UIKit
import os

/// What this device can afford, measured before the engine starts.
struct DeviceTier {
    let memoryLimitMB: Int
    let physicalMemoryMB: Int
    let model: String
    let supportsBCTextures: Bool

    static func probe() -> DeviceTier {
        var info = utsname(); uname(&info)
        let model = withUnsafeBytes(of: &info.machine) { String(decoding: $0.prefix { $0 != 0 }, as: UTF8.self) }
        let device = MTLCreateSystemDefaultDevice()
        return DeviceTier(memoryLimitMB: Self.processMemoryLimitMB(),
                          physicalMemoryMB: physicalMemoryMB(),
                          model: model,
                          supportsBCTextures: device?.supportsBCTextureCompression ?? false)
    }

    private static func physicalMemoryMB() -> Int {
        #if targetEnvironment(simulator)
        return Int(ProcessInfo.processInfo.environment["PG_SIM_PHYSICAL_MEMORY_MB"] ?? "") ?? 6144
        #else
        return Int(ProcessInfo.processInfo.physicalMemory / 1_048_576)
        #endif
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

    /// 6 GB phones (about 4.1 GB limit) are already at the edge on Performance.
    var recommended: GraphicsPreset {
        // Under ~3.6 GB (e.g. a 6 GB phone signed with a free Apple ID, which
        // cannot get the extra-memory entitlement) only the lightest preset fits.
        memoryLimitMB < 3600 ? .battery : memoryLimitMB < 5000 ? .performance : memoryLimitMB < 7000 ? .balanced : .quality
    }
    /// Presets that are allowed at all; higher ones are hidden.
    var allowed: [GraphicsPreset] {
        let normal: [GraphicsPreset]
        if memoryLimitMB < 3600 { normal = [.battery, .performance] }
        else if memoryLimitMB < 5000 { normal = [.battery, .performance, .balanced] }
        else if memoryLimitMB < 7000 { normal = [.battery, .performance, .balanced, .quality] }
        else { normal = [.battery, .performance, .balanced, .quality, .ultra] }
        return GraphicsPreset.displayOrder.filter {
            normal.contains($0) || ($0 == .extreme && physicalMemoryMB >= 10_240 && memoryLimitMB >= 3600)
        }
    }
    /// Presets shown with a warning because they may run out of memory or heat up.
    func risky(_ preset: GraphicsPreset) -> Bool { preset == .extreme ? memoryLimitMB < 8704 : preset.rawValue > recommended.rawValue }
    var summary: String { "\(model) · \(physicalMemoryMB / 1024) GB · app limit \(memoryLimitMB) MB\(supportsBCTextures ? " · BC textures" : "")" }
}

enum GraphicsConfiguration {
    /// Width/height for a preset and a 0.5...1.0 resolution scale, matching
    /// the screen's shape so the picture is not stretched.
    static func size(for preset: GraphicsPreset, scale: Double, screen: CGSize, matchScreenShape: Bool) -> (Int, Int) {
        let aspect = matchScreenShape && screen.height > 0 ? max(screen.width, screen.height) / min(screen.width, screen.height) : 16.0 / 9.0
        var height = Double(preset.height) * min(max(scale, 0.5), 1.0)
        height = max(height, 360)
        let width = min(height * aspect, 3840)
        func even(_ value: Double) -> Int { Int(value.rounded()) & ~1 }
        return (even(width), even(height))
    }

    /// Pass the chosen settings to the engine. Call before PGStartEngine.
    static func apply(_ settings: GameSettings, screen: CGSize) -> String {
        let preset = settings.graphicsPreset
        let (width, height) = size(for: preset, scale: settings.resolutionScale, screen: screen, matchScreenShape: settings.matchScreenShape)
        var options = preset.engineOptions
        if settings.sharperWorld && preset.rawValue >= GraphicsPreset.balanced.rawValue {
            // Increase the distance at which detailed geometry is drawn.
            // Keep textures at the original size on memory-constrained devices.
            let level: (lod: String, ped: String, vehicle: String)
            switch preset {
            case .balanced: level = ("0.30", "0.10", "0.10")
            case .quality:  level = ("0.50", "0.30", "0.30")
            case .ultra:    level = ("0.70", "0.50", "0.50")
            case .extreme:  level = ("0.70", "0.40", "0.40")
            default:       level = ("0", "0", "0")
            }
            let overrides = [
                "-lodScale=": level.lod,
                "-pedLodBias=": level.ped,
                "-vehicleLodBias=": level.vehicle
            ]
            for index in options.indices {
                for (prefix, value) in overrides where options[index].hasPrefix(prefix) {
                    options[index] = prefix + value
                }
            }
            if preset == .balanced && settings.tier.memoryLimitMB >= 5000,
               let index = options.firstIndex(where: { $0.hasPrefix("-textureQuality=") }) {
                options[index] = "-textureQuality=1"
            }
        }
        options = settings.viewDistance.apply(to: options)
        PGSetTextureClarity(UInt32(settings.textureClarity.rawValue))
        PGSetProcessMemoryBudget(preset.processBudgetMB)
        var pointers = options.map { strdup($0) }
        defer { pointers.forEach { free($0) } }
        pointers.withUnsafeMutableBufferPointer { buffer in
            buffer.baseAddress!.withMemoryRebound(to: UnsafePointer<CChar>?.self, capacity: buffer.count) {
                PGConfigureEngine($0, UInt32(buffer.count), Int32(width), Int32(height), settings.frameRateOption.engineFrameLimit)
            }
        }
        return "\(preset.title) \(width)×\(height) at \(settings.frameRateOption.rawValue) FPS"
    }
}
