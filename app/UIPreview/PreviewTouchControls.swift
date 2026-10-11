import UIKit

// Preview-only bridge. These tests exercise the real overlay's hit routing;
// the C queue checks exercise the separate engine handoff.
struct PGPadState {
    var buttons: UInt32 = 0
    var leftX: Float = 0, leftY: Float = 0, rightX: Float = 0, rightY: Float = 0
    var leftTrigger: Float = 0, rightTrigger: Float = 0
}
private var cameraTravel = CGPoint.zero
func PGQueueCameraLook(_ dx: Float, _ dy: Float) {
    cameraTravel.x += CGFloat(dx)
    cameraTravel.y += CGFloat(dy)
}
func PGResetCameraLook() { cameraTravel = .zero }

final class PreviewTouchController: UIViewController {
    private let controls = TouchControlsView(frame: .zero)
    private let result = UILabel()
    override var prefersStatusBarHidden: Bool { true }
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .darkGray
        controls.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(controls)
        NSLayoutConstraint.activate([
            controls.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            controls.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            controls.topAnchor.constraint(equalTo: view.topAnchor),
            controls.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        result.textColor = .white
        result.text = "Waiting for swipe"
        result.accessibilityIdentifier = "controls.swipe-result"
        result.isUserInteractionEnabled = false
        result.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(result)
        NSLayoutConstraint.activate([
            result.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            result.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -8)
        ])
        controls.openTrainer = { [weak self] in
            let navigation = UINavigationController(rootViewController: TrainerViewController())
            LauncherStyle.configure(navigation)
            navigation.sheetPresentationController?.detents = [.large()]
            self?.present(navigation, animated: true)
        }
        controls.inputChanged = { [weak self] in
            guard let self else { return }
            _ = self.controls.padState(elapsed: 1.0 / 60)
            if cameraTravel.x > 10 { self.result.text = "Swipe delivered right" }
            else if cameraTravel.x < -10 { self.result.text = "Swipe delivered left" }
        }
    }
}
