import CoreMotion
import CoreGraphics

/// Accelerometer steering, the way the classic played: raw gravity along
/// the device's x-axis maps straight to horizontal speed, lightly
/// low-pass filtered so the hero glides rather than jitters.
final class TiltInput {

    static let shared = TiltInput()

    private let motion = CMMotionManager()
    private var smoothedX: CGFloat = 0

    private init() {}

    func start() {
        guard motion.isAccelerometerAvailable, !motion.isAccelerometerActive else { return }
        motion.accelerometerUpdateInterval = 1.0 / 60.0
        motion.startAccelerometerUpdates()
    }

    func stop() {
        motion.stopAccelerometerUpdates()
        smoothedX = 0
    }

    /// Smoothed tilt in gravities, roughly -1...1, positive = tilt right,
    /// relative to the calibrated zero.
    func tilt() -> CGFloat {
        if let sample = motion.accelerometerData {
            let raw = CGFloat(sample.acceleration.x)
            smoothedX += (raw - smoothedX) * Tuning.horizontalSmoothing
        }
        return smoothedX - Settings.tiltZero
    }

    /// Store the current hold angle as "level" (the classic calibration
    /// option, added mid-2009).
    func calibrate() {
        if let sample = motion.accelerometerData {
            smoothedX = CGFloat(sample.acceleration.x)
        }
        Settings.tiltZero = smoothedX
    }

    /// Target horizontal velocity for the current tilt, clamped.
    func targetVelocity() -> CGFloat {
        let v = tilt() * Tuning.tiltToSpeed
        return max(-Tuning.maxHorizontalSpeed, min(Tuning.maxHorizontalSpeed, v))
    }
}
