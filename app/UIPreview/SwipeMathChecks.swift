import Foundation

@main struct SwipeMathChecks {
    static func main() {
        var input = SwipeLook()
        assert(input.consume(elapsed: 1.0 / 60, sensitivity: 1) == (0, 0))
        input.add(dx: 14, dy: -8)
        let first = input.consume(elapsed: 1.0 / 60, sensitivity: 1)
        assert(first.0 > 0 && first.1 > 0, "Swipe direction should match camera movement")
        assert(input.consume(elapsed: 1.0 / 60, sensitivity: 1) == (0, 0),
               "Camera must stop when finger stops")
        input.add(dx: -12, dy: 6)
        let opposite = input.consume(elapsed: 1.0 / 60, sensitivity: 1)
        assert(opposite.0 < 0 && opposite.1 < 0, "Reverse swipe should reverse camera")
        input.add(dx: 6, dy: 0)
        let slow = input.consume(elapsed: 1.0 / 60, sensitivity: 0.3)
        input.add(dx: 6, dy: 0)
        let fast = input.consume(elapsed: 1.0 / 60, sensitivity: 3)
        assert(fast.0 > slow.0, "Sensitivity must affect turning speed")
        input.add(dx: 6, dy: 0)
        let higher = input.consume(elapsed: 1.0 / 60, sensitivity: 6)
        input.add(dx: 6, dy: 0)
        let maximum = input.consume(elapsed: 1.0 / 60, sensitivity: 12)
        assert(higher.0 == fast.0 * 2 && maximum.0 == fast.0 * 4,
               "High sensitivities must not be clipped to the former 4x limit")
        input.add(dx: 100, dy: 100)
        input.reset()
        assert(input.consume(elapsed: 1.0 / 60, sensitivity: 1) == (0, 0),
               "Canceled gestures must not leave camera moving")
        input.add(dx: 0.125, dy: -0.125)
        let fine = input.consume(elapsed: 1.0 / 30, sensitivity: 1)
        input.add(dx: 0.125, dy: -0.125)
        assert(input.consume(elapsed: 1.0 / 120, sensitivity: 1) == fine,
               "Equal finger travel must not depend on frame duration")
        let original = ["-lodScale=0.2", "-pedLodBias=0", "-vehicleLodBias=0", "-textureQuality=1"]
        assert(ViewDistance.standard.apply(to: original) == original)
        let extended = ViewDistance.extended.apply(to: original)
        assert(extended.contains("-lodScale=0.32") && extended.contains("-textureQuality=1"))
        assert(ViewDistance.far.apply(to: original).contains("-lodScale=0.45"))
        print("SWIPE LOOK CHECKS PASSED")
    }
}
