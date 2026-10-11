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
