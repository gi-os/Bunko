import AVFoundation
import MediaPlayer
import UIKit

/// Turns pages with the volume buttons while the book is open: either button turns to the next
/// page, and the volume goes straight back to where it was. iOS gives apps no hardware-button
/// events outside the camera, so this watches the output volume, puts it back, and keeps the
/// system's volume pop-up away with a volume view off screen (the way e-readers that do this do).
@MainActor
final class VolumeButtons {
    var onPress: () -> Void = {}
    private(set) var isRunning = false
    private var observation: NSKeyValueObservation?
    private let volumeView = MPVolumeView(frame: CGRect(x: -400, y: -400, width: 120, height: 40))
    private var resting: Float = 0.5
    private var original: Float = 0.5

    func start(in view: UIView) {
        guard !isRunning else { return }
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.ambient, options: [.mixWithOthers])
        try? session.setActive(true)
        view.addSubview(volumeView)
        isRunning = true
        original = session.outputVolume
        resting = VolumeLevel.resting(original)
        if resting != original { set(resting) }
        observation = Self.watch(session, \.outputVolume) { [weak self] value in
            Task { @MainActor in self?.changed(to: value) }
        }
    }

    /// KVO reports a change on whatever thread made it, and the volume's comes from the audio
    /// system's own. A handler written in here would belong to the main actor, and Swift stops the
    /// app when one runs anywhere else (it did, opening and closing books, on the phone). This one
    /// belongs to no actor: it only hands the value over.
    nonisolated static func watch<Object: NSObject>(_ object: Object, _ keyPath: KeyPath<Object, Float>,
                                                   report: @escaping @Sendable (Float) -> Void) -> NSKeyValueObservation {
        object.observe(keyPath, options: [.new]) { _, change in
            if let value = change.newValue { report(value) }
        }
    }

    func stop() {
        guard isRunning else { return }
        observation?.invalidate()
        observation = nil
        isRunning = false
        if resting != original { set(original) }
        volumeView.removeFromSuperview()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func changed(to value: Float) {
        guard isRunning, VolumeLevel.isPress(resting: resting, now: value) else { return }
        onPress()
        set(resting)
    }

    private func set(_ value: Float) {
        (volumeView.subviews.first { $0 is UISlider } as? UISlider)?.setValue(value, animated: false)
    }
}

/// The arithmetic, apart so it can be tested.
enum VolumeLevel {
    /// One press of a volume button.
    static let step: Float = 1.0 / 16

    /// At either end a press can't move the volume, so there'd be nothing to notice: rest a step in.
    static func resting(_ volume: Float) -> Float { min(max(volume, step), 1 - step) }

    /// A press moved it away from where it rests (putting it back doesn't count).
    static func isPress(resting: Float, now: Float) -> Bool { abs(now - resting) > step / 4 }
}
