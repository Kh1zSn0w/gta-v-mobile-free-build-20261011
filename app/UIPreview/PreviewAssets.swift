import UIKit

// Only the preview target includes these stubs. UI tests never read or delete real game files.
extension Notification.Name { static let assetPreloadChanged = Notification.Name("AssetPreloadChanged") }
final class AssetPreloader {
    static let shared = AssetPreloader()
    enum Phase: Equatable { case unavailable(String), idle, downloading, paused, complete }
    var phase: Phase = .complete
    let cachedBytes: UInt64 = 21_190_000_000
    let totalBytes: UInt64 = 21_190_000_000
    let missingBytes: UInt64 = 0
    let fraction = 1.0
    let measured = true
    let removing = false
    var lastError: String? { nil }
    var bytesPerSecond: Double? { nil }
    var secondsRemaining: Double? { nil }
    func availableBytes() -> UInt64 { 40_000_000_000 }
    func refresh() {}
    func start() -> String? { nil }
    func pause() {}
    func cancel() {}
    func removeDownloads(_ completion: @escaping (String?) -> Void) { completion("Preview only. No files were removed.") }
    static func format(_ bytes: UInt64) -> String { String(format: "%.1f GB", Double(bytes) / 1e9) }
    static func formatDuration(_ seconds: Double) -> String { "\(Int(seconds))s" }
}
func PGConfigureEngine(_ options: UnsafePointer<UnsafePointer<CChar>?>, _ count: UInt32, _ width: Int32, _ height: Int32, _ interval: Int32) {}

func PGSetTextureClarity(_ amount: UInt32) {}
func PGSetProcessMemoryBudget(_ amount: UInt32) {}

// Simulator-only handoff model, separate from the real engine queue tests.
private var trainerPreviewStatus: UInt32 = 0
private var trainerPreviewInvincible = false
private var trainerPreviewToggles: Set<UInt32> = []
func PGTrainerReady() -> Bool { ProcessInfo.processInfo.arguments.contains("--trainer-unavailable") == false }
func PGTrainerRequest(_ command: UInt32) -> Bool {
    guard PGTrainerCommandAvailable(command), (1...181).contains(command), trainerPreviewStatus != 1 else { return false }
    trainerPreviewStatus = 1
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
        if command == 5 { trainerPreviewInvincible.toggle() }
        if (16...24).contains(command) || command == 30 {
            if trainerPreviewToggles.contains(command) { trainerPreviewToggles.remove(command) }
            else { trainerPreviewToggles.insert(command) }
        }
        if command == 18 { trainerPreviewToggles.remove(19) }
        if command == 19 { trainerPreviewToggles.remove(18) }
        if command == 31 { trainerPreviewToggles.remove(30) }
        if command == 25 { trainerPreviewToggles.removeAll(); trainerPreviewInvincible = false }
        if (101...114).contains(command) { wardrobePreviewSwapped = true }
        if command == 115 { wardrobePreviewSwapped = false }
        if command == 180 { wardrobePreviewSaved = true }
        if (120...167).contains(command) {
            let slot = Int((command - 120) / 4), action = (command - 120) % 4
            if action < 2 { wardrobePreviewStyles[slot] = (wardrobePreviewStyles[slot] + (action == 0 ? 1 : 2)) % 3; wardrobePreviewColours[slot] = 0 }
            else { wardrobePreviewColours[slot] = 1 - wardrobePreviewColours[slot] }
        }
        trainerPreviewStatus = 2
    }
    return true
}
func PGTrainerStatus() -> UInt32 { trainerPreviewStatus }
func PGTrainerInvincible() -> Bool { trainerPreviewInvincible }

func PGTrainerToggleState(_ command: UInt32) -> Bool { trainerPreviewToggles.contains(command) }

private var wardrobePreviewSwapped = false
private var wardrobePreviewSaved = false
private var wardrobePreviewStyles = Array(repeating: 0, count: 15)
private var wardrobePreviewColours = Array(repeating: 0, count: 15)
func PGTrainerCommandAvailable(_ command: UInt32) -> Bool {
    guard PGTrainerReady(), (1...181).contains(command) else { return false }
    if (101...115).contains(command) {
        if ProcessInfo.processInfo.arguments.contains("--trainer-story") { return false }
        if command == 115 { return wardrobePreviewSwapped }
    }
    return command != 181 || wardrobePreviewSaved
}
func PGTrainerSelectClothingSlot(_ slot: UInt32) {}
func PGTrainerClothingState(_ slot: UInt32) -> UInt64 {
    guard slot < 15, PGTrainerReady() else { return 0 }
    return UInt64(wardrobePreviewStyles[Int(slot)] + 1) | (3 << 16) | (UInt64(wardrobePreviewColours[Int(slot)]) << 32) | (2 << 48)
}
func PGSetVehicleCameraHold(_ enabled: Bool) {}

private var sandboxPreviewSaveStatus: UInt32 = 0
func PGSandboxSaveAvailable() -> Bool {
    PGTrainerReady() && !ProcessInfo.processInfo.arguments.contains("--trainer-story")
}
func PGSandboxSaveRequest() -> Bool {
    guard PGSandboxSaveAvailable(), sandboxPreviewSaveStatus != 1 else { return false }
    sandboxPreviewSaveStatus = 1
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { sandboxPreviewSaveStatus = 2 }
    return true
}
func PGSandboxSaveStatus() -> UInt32 { sandboxPreviewSaveStatus }

func PGSetMemoryCap(_ amount: Int32) {}
func PGLastInputDevice() -> Int32 { 0 }
func PGTargetingMode() -> Int32 { 1 }
enum GameFolder {
    static let isChosen = false
    static let testMapAvailable = false
}
