import Foundation

/// Incremental swipe input. A stationary finger does not keep rotating the camera.
struct SwipeLook {
    private var dx: Double = 0
    private var dy: Double = 0

    mutating func add(dx: Double, dy: Double) {
        guard dx.isFinite, dy.isFinite else { return }
        self.dx += dx
        self.dy += dy
    }

    mutating func reset() {
        dx = 0
        dy = 0
    }

    mutating func consume(elapsed: Double, sensitivity: Double) -> (Float, Float) {
        defer { reset() }
        guard elapsed.isFinite, elapsed > 0 else { return (0, 0) }
        let speed = max(0.3, min(12.0, sensitivity))
        // Queue travel, not a one-callback stick pulse. The engine converts it
        // using its own input interval, even when UI and game FPS differ.
        return (Float(max(-4096, min(4096, dx * speed))),
                Float(max(-4096, min(4096, -dy * speed))))
    }
}
