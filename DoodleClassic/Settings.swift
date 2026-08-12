import Foundation
import CoreGraphics

/// The classic options menu offered exactly this much: sound on/off,
/// a directional-shooting toggle (the launch build shot straight up;
/// angled shots were an update players could switch off), and tilt
/// calibration.
enum Settings {

    static var directionalShooting: Bool {
        get { UserDefaults.standard.bool(forKey: "directionalShooting") }
        set { UserDefaults.standard.set(newValue, forKey: "directionalShooting") }
    }

    /// Accelerometer x-value treated as "held level".
    static var tiltZero: CGFloat {
        get { CGFloat(UserDefaults.standard.double(forKey: "tiltZero")) }
        set { UserDefaults.standard.set(Double(newValue), forKey: "tiltZero") }
    }
}
