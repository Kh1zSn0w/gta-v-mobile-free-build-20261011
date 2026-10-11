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
    guard PGTrainerReady(), (1...85).contains(command), trainerPreviewStatus != 1 else { return false }
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
        trainerPreviewStatus = 2
    }
    return true
}
func PGTrainerStatus() -> UInt32 { trainerPreviewStatus }
func PGTrainerInvincible() -> Bool { trainerPreviewInvincible }

func PGTrainerToggleState(_ command: UInt32) -> Bool { trainerPreviewToggles.contains(command) }
