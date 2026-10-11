import UIKit
import MetalKit
import GameController
import AVFAudio

private func engineLog(_ message: UnsafePointer<CChar>?, _ context: UnsafeMutableRawPointer?) {
    guard let message, let context else { return }
    let line = String(cString: message)
    let controller = Unmanaged<NativePortViewController>.fromOpaque(context).takeUnretainedValue()
    DispatchQueue.main.async { controller.appendLog(line) }
}

final class NativePortViewController: UIViewController, MTKViewDelegate {
    private var metalView: MTKView!
    private var queue: MTLCommandQueue?
    private let output = UITextView()
    private let home = LauncherHomeView(frame: .zero)
    private var controllerLabel: UILabel { home.statusLabel }
    private let fpsLabel = UILabel()
    private var lastFPSLabelUpdate: CFTimeInterval = 0
    private var launchButton: UIButton { home.playButton }
    private var preloadLabel: UILabel { home.downloadLabel }
    private let audioEngine = AVAudioEngine()
    private var audioSource: AVAudioSourceNode?
    private var audioInterrupted = false
    private var displayLink: CADisplayLink?
    private var lastControllerPoll: CFTimeInterval?
    private var lines: [String] = []
    private var metrics: [String: String] = [:]
    private var logFile: URL?
    private let touchControls = TouchControlsView(frame: .zero)
    private let gyro = GyroInput()
    private var engineStarted = false
    private var bootedPreset = GameSettings.shared.graphicsPreset
    private var bootedMode: GameMode?
    private var stableTimer: Timer?
    private var padProof: PGPadState?
    private var tiltNeutral: Double?
    private var tiltSince: CFTimeInterval?
    private var tiltSmoothed: Double = 0
    private var touchControlsAvailable = false
    private var lastTouchInputTrace = ""
    private var movementProofStarted = false
    private var proofController: GCController?
    private var proofInputSamples = 0
    private var proofInputActive = false
    private var diagnosticsOverlay: UIView?
    private var pendingLaunch = false
    private var changingOrientation = false
    #if targetEnvironment(simulator)
    private var simulatorKeys = Set<UIKeyboardHIDUsage>()
    override var canBecomeFirstResponder: Bool { true }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        becomeFirstResponder()
    }
    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        for press in presses { if let key = press.key { simulatorKeys.insert(key.keyCode) } }
        super.pressesBegan(presses, with: event)
    }
    override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        for press in presses { if let key = press.key { simulatorKeys.remove(key.keyCode) } }
        super.pressesEnded(presses, with: event)
    }
    override func pressesCancelled(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        simulatorKeys.removeAll()
        super.pressesCancelled(presses, with: event)
    }
    #endif

    override var prefersStatusBarHidden: Bool { true }
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        engineStarted || pendingLaunch ? .landscape : .allButUpsideDown
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // Wait for the landscape layout before choosing the engine's back-buffer size.
        if pendingLaunch && !changingOrientation && view.bounds.width > view.bounds.height {
            pendingLaunch = false
            startEngine()
        }
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        changingOrientation = true
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: nil) { [weak self] _ in
            guard let self else { return }
            self.changingOrientation = false
            self.view.setNeedsLayout()
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        UIApplication.shared.isIdleTimerDisabled = true
        let device = MTLCreateSystemDefaultDevice()
        metalView = MTKView(frame: .zero, device: device)
        queue = device?.makeCommandQueue()
        metalView.delegate = self
        metalView.clearColor = MTLClearColorMake(0.025, 0.025, 0.035, 1)
        metalView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(metalView)

        view.backgroundColor = LauncherStyle.background
        view.tintColor = LauncherStyle.accent
        home.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(home)
        diagnosticsOverlay = home
        launchButton.addTarget(self, action: #selector(chooseGameMode), for: .touchUpInside)
        home.openSection = { [weak self] section in
            guard let self, !self.engineStarted, !self.pendingLaunch else { return }
            if section == .connection { self.askForAssetServer() }
            else { self.showSettings(section: section) }
        }
        output.isEditable = false
        output.isHidden = !ProcessInfo.processInfo.arguments.contains("--show-log")
        output.backgroundColor = UIColor.black.withAlphaComponent(0.75)
        output.textColor = .white
        output.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        output.translatesAutoresizingMaskIntoConstraints = false
        home.addSubview(output)
        NSLayoutConstraint.activate([
            home.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            home.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            home.topAnchor.constraint(equalTo: view.topAnchor),
            home.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            output.leadingAnchor.constraint(equalTo: home.safeAreaLayoutGuide.leadingAnchor, constant: 20),
            output.trailingAnchor.constraint(equalTo: home.safeAreaLayoutGuide.trailingAnchor, constant: -20),
            output.bottomAnchor.constraint(equalTo: home.safeAreaLayoutGuide.bottomAnchor, constant: -12),
            output.heightAnchor.constraint(equalTo: home.heightAnchor, multiplier: 0.25)
        ])
        let arguments = ProcessInfo.processInfo.arguments
        if let index = arguments.firstIndex(of: "--game-mode"), index + 1 < arguments.count {
            GameSettings.shared.gameMode = arguments[index + 1] == "story" ? .story : .sandbox
        }
        refreshModeChoice()
        updateServerStatus()
        if !GameSettings.shared.assetServer.isEmpty { testAssetServer() }
        fpsLabel.text = "— FPS"
        fpsLabel.isHidden = true
        fpsLabel.font = .monospacedDigitSystemFont(ofSize: 12, weight: .semibold)
        fpsLabel.textColor = .white
        fpsLabel.textAlignment = .center
        fpsLabel.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        fpsLabel.layer.cornerRadius = 6
        fpsLabel.clipsToBounds = true
        fpsLabel.isUserInteractionEnabled = false
        fpsLabel.accessibilityLabel = "Game frame rate"
        fpsLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(fpsLabel)
        touchControls.translatesAutoresizingMaskIntoConstraints = false
        touchControls.isHidden = true
        touchControls.inputChanged = { [weak self] in self?.pollController() }
        touchControls.openSettings = { [weak self] in self?.showSettings() }
        touchControls.openTrainer = { [weak self] in self?.showTrainer() }
        view.addSubview(touchControls)
        NSLayoutConstraint.activate([
            touchControls.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            touchControls.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            touchControls.topAnchor.constraint(equalTo: view.topAnchor),
            touchControls.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        NSLayoutConstraint.activate([
            fpsLabel.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 12),
            fpsLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            fpsLabel.widthAnchor.constraint(equalToConstant: 68),
            fpsLabel.heightAnchor.constraint(equalToConstant: 24)
        ])
        NSLayoutConstraint.activate([
            metalView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            metalView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            metalView.topAnchor.constraint(equalTo: view.topAnchor),
            metalView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        logFile = directory.appendingPathComponent("native-port.log")
        try? Data().write(to: logFile!)
        appendLog("Native UIKit + Metal host. Engine compiled into the app; no WebView or JIT.")
        appendLog("Metal device: \(device?.name ?? "unavailable")")
        displayLink = CADisplayLink(target: self, selector: #selector(pollController))
        updatePollingRate()
        displayLink?.add(to: .main, forMode: .common)
        NotificationCenter.default.addObserver(self, selector: #selector(controllerChanged), name: .GCControllerDidDisconnect, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(controllerChanged), name: .GCControllerDidConnect, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(releaseTouchControls), name: UIApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(leftApp), name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(audioInterruption(_:)), name: AVAudioSession.interruptionNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(audioConfigurationChanged), name: .AVAudioEngineConfigurationChange, object: audioEngine)
        NotificationCenter.default.addObserver(self, selector: #selector(resumeAudio), name: UIApplication.didBecomeActiveNotification, object: nil)
        if let message = GameSettings.shared.recoverFromFailedBoot() {
            appendLog(message)
            controllerLabel.text = message
            controllerLabel.numberOfLines = 0
            controllerLabel.isHidden = false
        }
        if ProcessInfo.processInfo.arguments.contains("--touch-controls-preview") {
            diagnosticsOverlay?.isHidden = true
            touchControlsAvailable = true
            fpsLabel.isHidden = false
            touchControls.isHidden = false
        }
        NotificationCenter.default.addObserver(self, selector: #selector(preloadChanged), name: .assetPreloadChanged, object: nil)
        // Continue an unfinished "Download all game files" after a relaunch.
        AssetPreloader.shared.resumeIfNeeded()
        if ProcessInfo.processInfo.arguments.contains("--preload-autostart") {
            // Debug: start the download without tapping (simulator checks).
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                if let message = AssetPreloader.shared.start() { self.appendLog("Preload refused: " + message) }
            }
        }
        if ProcessInfo.processInfo.arguments.contains("--open-settings") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { self.showSettings() }
        }
        if ProcessInfo.processInfo.arguments.contains("--boot-engine") {
            DispatchQueue.main.async { self.beginGameLaunch() }
        }
    }

    @objc private func preloadChanged() {
        let summary = AssetPreloader.shared.launchSummary
        preloadLabel.text = summary
        preloadLabel.isHidden = summary == nil
        refreshHomeDetails()
    }

    func appendLog(_ line: String) {
        NSLog("[native-port] %@", line)
        if line.hasPrefix("ASSET_WARM_PROGRESS ") {
            let parts = line.split(separator: " ")
            if parts.count >= 3 {
                let size = Double(parts[2]).map { String(format: "%.1f GB", $0 * 1048576 / 1_000_000_000) } ?? ""
                home.setLoading("Preparing game files · \(parts[1])% · \(size)")
            }
        }
        if line == "ASSET_WARM_COMPLETE" { home.setLoading("Loading your game…") }
        if line == "WORLD_READY", ProcessInfo.processInfo.arguments.contains("--capture-world") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 35) { PGCaptureNativeFrame("optimized-world") }
        }
        if line == "WORLD_READY", ProcessInfo.processInfo.arguments.contains("--verify-pad"), !movementProofStarted {
            movementProofStarted = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 30) { self.verifyVirtualPad() }
        }
        if line == "WORLD_READY", ProcessInfo.processInfo.arguments.contains("--verify-movement"), !movementProofStarted {
            movementProofStarted = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 30) { self.verifyMovement() }
        }
        if line == "WORLD_READY" { PGSetTargetingMode(Int32(GameSettings.shared.targetingMode)) }
        if line == "WORLD_READY", stableTimer == nil {
            // Three minutes in the world counts as a launch that fits in memory.
            stableTimer = Timer.scheduledTimer(withTimeInterval: 180, repeats: false) { _ in GameSettings.shared.markBootStable() }
        }
        if line == "WORLD_READY" || line.contains("\"label\":\"First frame\"") {
            diagnosticsOverlay?.isHidden = true
            touchControlsAvailable = true
            fpsLabel.isHidden = false
        }
        if line.hasPrefix("Native boot stopped:") || line == "iOS could not reserve the engine memory." {
            audioEngine.stop()
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            metalView.isPaused = true
            home.setLoading("Launch stopped. Close and reopen the app to try again.")
            showLaunchError("The game couldn't finish starting. Your downloaded files and saves are unchanged. Close and reopen the app, then try a lighter graphics preset.")
        }
        if let logFile, let data = (line + "\n").data(using: .utf8),
           let handle = try? FileHandle(forWritingTo: logFile) {
            defer { try? handle.close() }
            do { try handle.seekToEnd(); try handle.write(contentsOf: data) } catch {}
        }
        for key in ["[wgpu] fps:", "[wgpu] draw costs", "Native frame costs:", "Phone memory:", "WORLD_READY"] where line.hasPrefix(key) {
            metrics[key] = line
            if let data = try? JSONSerialization.data(withJSONObject: metrics, options: [.prettyPrinted, .sortedKeys]), let logFile {
                try? data.write(to: logFile.deletingLastPathComponent().appendingPathComponent("native-metrics.json"), options: .atomic)
            }
        }
        lines.append(line)
        if lines.count > 500 { lines.removeFirst(lines.count - 500) }
        guard diagnosticsOverlay?.isHidden != true else { return }
        output.text = lines.joined(separator: "\n")
        if !output.text.isEmpty { output.scrollRangeToVisible(NSRange(location: output.text.utf16.count - 1, length: 1)) }
    }

    private func refreshModeChoice() {
        refreshHomeDetails()
    }

    private func refreshHomeDetails() {
        let settings = GameSettings.shared
        home.setDetail("\(settings.graphicsPreset.title) · \(settings.frameRateOption.rawValue) FPS · \(Int((settings.resolutionScale * 100).rounded()))% resolution", for: .graphics)
        home.setDetail("Swipe camera, sensitivity and aim", for: .controls)
        home.setDetail("Gyro aiming and tilt steering", for: .motion)
        let preloader = AssetPreloader.shared
        preloadLabel.text = preloader.launchSummary
        preloadLabel.isHidden = preloader.launchSummary == nil
        switch preloader.phase {
        case .complete:
            home.setDetail("Downloaded locally", for: .files)
        case .downloading:
            home.setDetail("Downloading · \(Int(preloader.fraction * 100))%", for: .files)
        case .paused:
            home.setDetail("Download paused · \(Int(preloader.fraction * 100))%", for: .files)
        default:
            home.setDetail("Download, storage and offline play", for: .files)
        }
    }

    @objc private func chooseGameMode() {
        guard !engineStarted, !pendingLaunch, presentedViewController == nil else { return }
        let picker = GameModeViewController()
        picker.modalPresentationStyle = .pageSheet
        picker.sheetPresentationController?.detents = [.custom(identifier: .init("modeChooser")) { min(460, $0.maximumDetentValue) }]
        picker.sheetPresentationController?.prefersGrabberVisible = true
        picker.sheetPresentationController?.preferredCornerRadius = 30
        picker.selectedMode = { [weak self] mode in
            GameSettings.shared.gameMode = mode
            self?.beginGameLaunch()
        }
        present(picker, animated: true)
    }

    private func beginGameLaunch() {
        guard !engineStarted, !pendingLaunch else { return }
        pendingLaunch = true
        home.setLoading("Preparing to play…")
        setNeedsUpdateOfSupportedInterfaceOrientations()
        guard let scene = view.window?.windowScene else {
            pendingLaunch = false
            home.setLoading(nil)
            return
        }
        scene.requestGeometryUpdate(.iOS(interfaceOrientations: .landscape)) { [weak self] error in
            DispatchQueue.main.async {
                guard let self, !self.engineStarted else { return }
                self.pendingLaunch = false
                self.home.setLoading(nil)
                self.setNeedsUpdateOfSupportedInterfaceOrientations()
                self.showLaunchError("Rotate your iPhone to landscape and try again. \(error.localizedDescription)")
            }
        }
        view.setNeedsLayout()
    }

    private func showLaunchError(_ message: String) {
        guard presentedViewController == nil else { return }
        let alert = UIAlertController(title: "Couldn't start the game", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    @objc private func startEngine() {
        guard !engineStarted else { return }
        if GameSettings.shared.gameModeChoice == nil {
            // Automated launches without a choice keep the old sandbox start.
            guard ProcessInfo.processInfo.arguments.contains("--boot-engine") else { return }
        }
        guard let path = EnginePaths.manifest else {
            appendLog("Asset manifest is missing from the app bundle.")
            home.setLoading(nil)
            showLaunchError("The game's file list is missing. Reinstall this update over the existing app without deleting it.")
            return
        }
        metalView.isPaused = true
        metalView.delegate = nil
        // Dawn owns the drawable size from here; MTKView must not reset it on layout.
        metalView.autoResizeDrawable = false
        PGAttachMetalLayer(Unmanaged.passUnretained(metalView.layer).toOpaque())
        launchButton.isEnabled = false
        engineStarted = true
        let mode = GameSettings.shared.gameMode
        bootedMode = mode
        PGSetStartMode(Int32(mode.rawValue))
        appendLog("Game mode: \(mode.title)")
        bootedPreset = GameSettings.shared.graphicsPreset
        appendLog("Graphics: " + GraphicsConfiguration.apply(GameSettings.shared, screen: view.bounds.size))
        appendLog("Device: " + GameSettings.shared.tier.summary)
        GameSettings.shared.markBootStarted()
        home.setLoading("Loading your game…")
        appendLog("Native touch controls support held buttons, sprint and weapon selection.")
        startAudio()
        let (root, rootNote) = EnginePaths.filesRoot()
        if let rootNote { appendLog(rootNote) }
        PGSetAssetServer(GameSettings.shared.assetServer)
        AssetPreloader.shared.engineRunning = true
        path.withCString { manifest in
            root.withCString { PGStartEngine(manifest, $0, engineLog, Unmanaged.passUnretained(self).toOpaque()) }
        }
    }

    private func verifyMovement() {
        let testController = GCController.withExtendedGamepad()
        guard let pad = testController.extendedGamepad else {
            appendLog("Movement proof needs the native touch controller.")
            return
        }
        appendLog("Movement proof: capturing the world before native controller input.")
        PGCaptureNativeFrame("movement-before")
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            self.proofController = testController
            self.proofInputActive = true
            self.proofInputSamples = 0
            pad.leftThumbstick.setValueForXAxis(0, yAxis: 0.8)
            pad.rightThumbstick.setValueForXAxis(0.25, yAxis: 0)
            self.appendLog("Movement proof: native controller sticks active.")
            DispatchQueue.main.asyncAfter(deadline: .now() + 6) {
                self.proofInputActive = false
                self.appendLog("Movement proof: \(self.proofInputSamples) controller samples delivered to the engine.")
                pad.leftThumbstick.setValueForXAxis(0, yAxis: 0)
                pad.rightThumbstick.setValueForXAxis(0, yAxis: 0)
                self.proofController = nil
                PGCaptureNativeFrame("movement-after")
                self.appendLog("Movement proof: native controller sticks released.")
            }
        }
    }

    /// Simulator proof that the engine accepts the virtual controller and
    /// that controller aiming locks on: walk, pick a gun from the wheel, aim.
    private func verifyVirtualPad() {
        func log(_ step: String) { appendLog("Pad proof: \(step); input device \(PGLastInputDevice()), targeting mode \(PGTargetingMode())") }
        func pad(_ build: (inout PGPadState) -> Void) -> PGPadState { var s = PGPadState(); build(&s); return s }
        let steps: [(Double, PGPadState?, String?, String?)] = [
            (0, PGPadState(), "before input", "pad-before"),
            (0.5, pad { $0.leftY = 0.8 }, nil, nil),
            (3.5, PGPadState(), "walked forward", "pad-moved"),
            // Weapon wheel: hold L1 and point the right stick at a slot.
            (4.5, pad { $0.padButtons = .l1 }, nil, nil),
            (5.3, pad { $0.padButtons = .l1; $0.rightX = 1 }, "wheel open, pointing right", "pad-wheel"),
            (6.3, PGPadState(), "wheel released", nil),
            (8.0, pad { $0.leftTrigger = 1 }, nil, nil),
            (9.2, pad { $0.leftTrigger = 1 }, "aim held", "pad-aim"),
            (9.4, pad { $0.leftTrigger = 1; $0.rightX = 0.35 }, nil, nil),
            (10.0, pad { $0.leftTrigger = 1; $0.rightTrigger = 1 }, nil, nil),
            (10.6, pad { $0.leftTrigger = 1; $0.rightTrigger = 1 }, "aim and fire", "pad-fire"),
            (11.5, PGPadState(), "released", nil)]
        for (time, state, message, frame) in steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + time) {
                if let state { self.padProof = state }
                if let message { log(message) }
                if let frame { PGCaptureNativeFrame(frame) }
            }
        }
    }

    private func startAudio() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setPreferredSampleRate(48000)
            try session.setPreferredIOBufferDuration(0.010666667)
            try session.setActive(true)
            let format = AVAudioFormat(standardFormatWithSampleRate: 48000, channels: 2)!
            if audioSource == nil {
                let source = AVAudioSourceNode(format: format) { _, _, count, audioBufferList in
                    let buffers = UnsafeMutableAudioBufferListPointer(audioBufferList)
                    guard buffers.count >= 2, let left = buffers[0].mData, let right = buffers[1].mData else { return noErr }
                    PGFillAudio(left.assumingMemoryBound(to: Float.self), right.assumingMemoryBound(to: Float.self), count)
                    return noErr
                }
                audioSource = source
                audioEngine.attach(source)
            }
            audioEngine.connect(audioSource!, to: audioEngine.mainMixerNode, format: format)
            PGResetAudio()
            #if targetEnvironment(simulator)
            // Simulator runs are silent unless --sound is passed (test runs play through the Mac's speakers).
            if !ProcessInfo.processInfo.arguments.contains("--sound") { audioEngine.mainMixerNode.outputVolume = 0 }
            #endif
            audioEngine.prepare()
            try audioEngine.start()
        } catch { appendLog("Native audio setup failed: \(error.localizedDescription)") }
    }

    @objc private func audioInterruption(_ notification: Notification) {
        if !Thread.isMainThread {
            DispatchQueue.main.async { [weak self] in self?.audioInterruption(notification) }
            return
        }
        guard let raw = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: raw) else { return }
        if type == .began {
            audioInterrupted = true
            audioEngine.pause()
        } else {
            audioInterrupted = false
            let rawOptions = notification.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
            if AVAudioSession.InterruptionOptions(rawValue: rawOptions).contains(.shouldResume) { resumeAudio() }
        }
    }

    @objc private func audioConfigurationChanged() {
        DispatchQueue.main.async { [weak self] in self?.resumeAudio() }
    }

    @objc private func resumeAudio() {
        guard engineStarted, audioSource != nil, !audioInterrupted,
              UIApplication.shared.applicationState == .active, !audioEngine.isRunning else { return }
        startAudio()
    }

    private func updatePollingRate() {
        let requested = GameSettings.shared.frameRateOption.rawValue
        let supported = max(30, min(requested, UIScreen.main.maximumFramesPerSecond))
        displayLink?.preferredFrameRateRange = CAFrameRateRange(
            minimum: 30, maximum: Float(supported), preferred: Float(supported)
        )
    }

    @objc private func controllerChanged() { pollController() }

    // MARK: Game file server

    /// Shows the server and whether it answers; Play needs a working server.
    private func updateServerStatus(_ status: String? = nil) {
        let server = GameSettings.shared.assetServer
        let detail = server.isEmpty ? "Add your game file server" : (status ?? "Manage your game file server")
        home.setDetail(detail, for: .connection)
    }
    private func askForAssetServer() {
        let alert = UIAlertController(title: "Game file server", message: "Connect to the computer holding your game files. Downloaded files and saves stay on this iPhone.", preferredStyle: .alert)
        alert.addTextField { field in
            field.text = GameSettings.shared.assetServer
            field.placeholder = "https://my-pc.tailnet-name.ts.net"
            field.keyboardType = .URL
            field.autocapitalizationType = .none
            field.autocorrectionType = .no
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Save and test", style: .default) { [weak self, weak alert] _ in
            GameSettings.shared.assetServer = alert?.textFields?.first?.text ?? ""
            self?.testAssetServer()
        })
        present(alert, animated: true)
    }
    /// Checks that the server answers with the game's file list.
    private func testAssetServer() {
        var server = GameSettings.shared.assetServer
        while server.hasSuffix("/") { server.removeLast() }
        guard let url = URL(string: server + "/data/manifest.json"), url.scheme?.hasPrefix("http") == true else {
            updateServerStatus("not a valid address"); return
        }
        updateServerStatus("checking…")
        var request = URLRequest(url: url, timeoutInterval: 10)
        request.httpMethod = "HEAD"
        URLSession.shared.dataTask(with: request) { [weak self] _, response, error in
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            DispatchQueue.main.async {
                if code == 200 { self?.updateServerStatus("connected ✓") }
                else if let error { self?.updateServerStatus("can't connect (\(error.localizedDescription))") }
                else { self?.updateServerStatus("answered \(code); is the address the folder with data/ and b/?") }
            }
        }.resume()
    }
    @objc private func leftApp() { if stableTimer?.isValid != false { GameSettings.shared.markBootInterrupted() } }

    private func showTrainer() {
        guard engineStarted, presentedViewController == nil else { return }
        releaseTouchControls()
        let navigation = UINavigationController(rootViewController: TrainerViewController())
        LauncherStyle.configure(navigation)
        navigation.presentationController?.delegate = self
        navigation.sheetPresentationController?.detents = [.large()]
        navigation.sheetPresentationController?.prefersGrabberVisible = true
        navigation.sheetPresentationController?.preferredCornerRadius = 28
        present(navigation, animated: true)
    }

    private func showSettings(section: LauncherSection? = nil) {
        guard presentedViewController == nil else { return }
        touchControls.reset()
        let controller = SettingsViewController(engineRunning: engineStarted, runningMode: bootedMode, initialSection: section)
        controller.gameModeChanged = { [weak self] in self?.refreshModeChoice() }
        controller.resolutionChanged = { [weak self] in self?.applyLiveResolution() }
        controller.controlsChanged = { [weak self] in self?.touchControls.updateVisibility() }
        controller.targetingChanged = { PGSetTargetingMode(Int32(GameSettings.shared.targetingMode)) }
        let navigation = UINavigationController(rootViewController: controller)
        LauncherStyle.configure(navigation)
        navigation.presentationController?.delegate = self
        navigation.sheetPresentationController?.detents = [.large()]
        navigation.sheetPresentationController?.prefersGrabberVisible = true
        navigation.sheetPresentationController?.preferredCornerRadius = 28
        controller.settingsChanged = { [weak self] in
            self?.refreshHomeDetails()
            self?.updatePollingRate()
        }
        present(navigation, animated: true)
    }
    /// The engine follows back-buffer size changes while running.
    private func applyLiveResolution() {
        guard engineStarted else { return }
        let settings = GameSettings.shared
        let (width, height) = GraphicsConfiguration.size(for: bootedPreset, scale: settings.resolutionScale, screen: view.bounds.size, matchScreenShape: settings.matchScreenShape)
        PGSetBackBufferSize(Int32(width), Int32(height))
        appendLog("Graphics: live resize to \(width)×\(height)")
    }
    @objc private func releaseTouchControls() {
        touchControls.reset(publish: false)
        gyro.setRunning(false, orientation: .landscapeRight)
        lastControllerPoll = nil
        #if targetEnvironment(simulator)
        simulatorKeys.removeAll()
        #endif
        PGUpdateVirtualPad(PGPadState())
    }
    @objc private func pollController() {
        guard UIApplication.shared.applicationState == .active else {
            touchControls.reset(publish: false)
            lastControllerPoll = nil
            PGUpdateVirtualPad(PGPadState())
            return
        }
        if presentedViewController != nil {
            PGUpdateVirtualPad(PGPadState())
            PGResetCameraLook()
            return
        }
        let now = CACurrentMediaTime()
        if now - lastFPSLabelUpdate >= 0.25 {
            let fps = PGRenderedFramesPerSecond()
            fpsLabel.text = fps > 0 ? String(format: "%.0f FPS", fps) : "— FPS"
            lastFPSLabelUpdate = now
        }
        let elapsed = lastControllerPoll.map { now - $0 } ?? (1.0 / 60.0)
        lastControllerPoll = now
        if let padProof { PGUpdateVirtualPad(padProof); return }
        // Everything reaches the engine as its own controller, so controller
        // features (assisted aim, analog steering and throttle) apply.
        var state = PGPadState()
        if let controller = GCController.controllers().first(where: { $0.extendedGamepad != nil }), let pad = controller.extendedGamepad {
            state = PGPadState(gamepad: pad)
        }
        touchControls.isHidden = !touchControlsAvailable
        var vehicle = touchControlsAvailable ? PGCurrentTouchContext() : 0
        var pauseMenu = PGPauseMenuActive()
        // Debug: --preview-context <vehicle type + 1 | menu> to review a layout.
        let arguments = ProcessInfo.processInfo.arguments
        if let i = arguments.firstIndex(of: "--preview-context"), i + 1 < arguments.count {
            if arguments[i + 1] == "menu" { pauseMenu = true } else { vehicle = UInt32(arguments[i + 1]) ?? 0 }
        }
        if touchControlsAvailable {
            touchControls.updateContext(vehicle: vehicle, pauseMenu: pauseMenu)
            let touch = touchControls.padState(elapsed: elapsed)
            if ProcessInfo.processInfo.arguments.contains("--trace-touch-controls") {
                let sample = String(format: "Touch pad: buttons=%u move=%.2f,%.2f look=%.2f,%.2f triggers=%.2f,%.2f device=%d", touch.buttons, touch.leftX, touch.leftY, touch.rightX, touch.rightY, touch.leftTrigger, touch.rightTrigger, PGLastInputDevice())
                if sample != lastTouchInputTrace { lastTouchInputTrace = sample; appendLog(sample) }
            }
            state.merge(touch)
        }
        #if targetEnvironment(simulator)
        var keys = PGPadState()
        func held(_ key: UIKeyboardHIDUsage) -> Float { simulatorKeys.contains(key) ? 1 : 0 }
        keys.leftX = held(.keyboardD) - held(.keyboardA)
        keys.leftY = held(.keyboardW) - held(.keyboardS)
        keys.rightX = held(.keyboardRightArrow) - held(.keyboardLeftArrow)
        keys.rightY = held(.keyboardUpArrow) - held(.keyboardDownArrow)
        keys.leftTrigger = held(.keyboardZ); keys.rightTrigger = held(.keyboardX)
        let map: [(UIKeyboardHIDUsage, PadButtons)] = [(.keyboardSpacebar, .x), (.keyboardLeftShift, .a), (.keyboardF, .y), (.keyboardR, .b),
            (.keyboardQ, .r1), (.keyboardTab, .l1), (.keyboardV, .select), (.keyboardEscape, .start), (.keyboardE, .l3),
            (.keyboardReturnOrEnter, .a), (.keyboardDeleteOrBackspace, .b), (.keyboardI, .up), (.keyboardK, .down), (.keyboardJ, .left), (.keyboardL, .right)]
        var keyButtons = PadButtons()
        for (key, bit) in map where simulatorKeys.contains(key) { keyButtons.insert(bit) }
        keys.padButtons = keyButtons
        state.merge(keys)
        #endif
        // Optional gyro: phone rotation adds to the right stick.
        let settings = GameSettings.shared
        let onFoot = vehicle == 0
        let driving = touchControls.context.driving
        let tiltWanted = touchControlsAvailable && driving && settings.tiltSteer != .off
        let gyroWanted = touchControlsAvailable && ((settings.gyroAim != .off && !touchControls.flyingWithRightStick && touchControls.context != .menu) || tiltWanted)
        let orientation = view.window?.windowScene?.interfaceOrientation ?? .landscapeRight
        gyro.setRunning(gyroWanted, orientation: orientation)
        if tiltWanted, let angle = gyro.steeringAngle() {
            // The neutral angle is however the phone is held on entering.
            if tiltSince == nil { tiltSince = now }
            if tiltNeutral == nil, now - (tiltSince ?? now) > 0.15 { tiltNeutral = angle }
            if let neutral = tiltNeutral {
                var degrees = (angle - neutral) * 180 / .pi
                degrees = abs(degrees) < 1.5 ? 0 : degrees - copysign(1.5, degrees)
                let raw = max(-1, min(1, degrees / settings.tiltFullLock))
                let curved = copysign(pow(abs(raw), 1.4), raw)
                tiltSmoothed += (curved - tiltSmoothed) * min(1, elapsed / 0.06)
                let fadeIn = min(1, (now - (tiltSince ?? now) - 0.15) / 0.3)
                let tilt = Float(tiltSmoothed * max(0, fadeIn))
                if settings.tiltSteer == .full && abs(state.leftX) < 0.05 { state.leftX = tilt }
                else if settings.tiltSteer == .assist { state.leftX = max(-1, min(1, state.leftX + tilt * 0.6)) }
            }
        } else if !driving {
            tiltNeutral = nil; tiltSince = nil; tiltSmoothed = 0
        }
        if gyroWanted && settings.gyroAim != .off {
            let aiming = touchControls.aiming || state.leftTrigger > 0.1
            let active = aiming || (settings.gyroAim == .always && onFoot)
            let rate = gyro.rate(active: active, elapsed: elapsed)
            // About 2 rad/s of phone rotation is a full stick at sensitivity 1.
            let gain = 350 * settings.gyroSensitivity
            let invert: CGFloat = settings.gyroInvertY ? -1 : 1
            state.rightX = max(-1, min(1, state.rightX + TouchControlsView.lookAxis(rate.dx * gain)))
            state.rightY = max(-1, min(1, state.rightY - TouchControlsView.lookAxis(rate.dy * gain * invert)))
        }
        PGUpdateVirtualPad(state)
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}
    func draw(in view: MTKView) {
        guard let descriptor = view.currentRenderPassDescriptor, let drawable = view.currentDrawable,
              let command = queue?.makeCommandBuffer(), let encoder = command.makeRenderCommandEncoder(descriptor: descriptor) else { return }
        encoder.endEncoding()
        command.present(drawable)
        command.commit()
    }
}

extension NativePortViewController: UIAdaptivePresentationControllerDelegate {
    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        refreshHomeDetails()
    }
}
