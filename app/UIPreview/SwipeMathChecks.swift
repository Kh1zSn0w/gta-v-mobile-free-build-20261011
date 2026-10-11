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
        input.add(dx: 100, dy: 100)
        input.reset()
        assert(input.consume(elapsed: 1.0 / 60, sensitivity: 1) == (0, 0),
               "Canceled gestures must not leave camera moving")
        print("SWIPE LOOK CHECKS PASSED")
    }
}
