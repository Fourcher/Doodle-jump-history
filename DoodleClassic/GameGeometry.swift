import CoreGraphics
import Foundation

/// The game is authored in the original 2009 iPhone coordinate space:
/// 320 points wide, 480 points tall on a 3:2 screen. Modern devices keep
/// the 320-pt width (so every horizontal metric matches the original) and
/// extend the height to fill the taller screen.
enum GameGeometry {
    static let worldWidth: CGFloat = 320
    /// Height of the original reference screen; vertical tuning values
    /// below are expressed relative to this.
    static let referenceHeight: CGFloat = 480
    /// Actual scene height for this device, set once at launch.
    static var sceneHeight: CGFloat = 480
}

/// Every gameplay tuning constant in one place, in the 320-pt coordinate
/// space, seconds, and points-per-second.
///
/// The vertical numbers reproduce the measured classic feel: a normal
/// bounce tops out at ~150 pt (≈31% of the reference screen) on a floaty
/// ~1.36-second parabola, and the boost items climb the same distances
/// the era's guides measured for them — spring 352, trampoline 520,
/// propeller hat ~1,700, spring shoes 6 spring-height bounces, jetpack
/// ~3,300. Score equals altitude: one reference screen ≈ 480 points.
enum Tuning {
    // Gravity & bounce
    static let gravity: CGFloat = -650
    static let jumpVelocity: CGFloat = 440       // apex ≈ 149 pt
    static let springVelocity: CGFloat = 676     // apex ≈ 352 pt
    static let trampolineVelocity: CGFloat = 822 // apex ≈ 520 pt
    static let maxFallSpeed: CGFloat = -1000

    // Worn boosts.
    // Propeller: short spin-up to a slow cruise, ~1,700 pt gained overall
    // (including the ballistic coast after it dies).
    static let propellerDuration: TimeInterval = 3.6
    static let propellerCruiseSpeed: CGFloat = 450
    static let propellerSpinupTime: TimeInterval = 0.3
    // Jetpack: ignition ramp, fast cruise, sputtering burnout — ~3,300 pt
    // gained overall.
    static let jetpackDuration: TimeInterval = 4.4
    static let jetpackCruiseSpeed: CGFloat = 800
    static let jetpackIgnitionTime: TimeInterval = 0.5
    static let jetpackBurnoutTime: TimeInterval = 0.8
    static let jetpackBurnoutFloor: CGFloat = 440
    static let springShoeBounces = 6               // spring-strength each
    static let shieldDuration: TimeInterval = 8.0

    // Tilt steering: proportional, barely smoothed, quick to cross the screen
    static let tiltToSpeed: CGFloat = 400          // pt/s per g of tilt
    static let maxHorizontalSpeed: CGFloat = 300
    static let horizontalSmoothing: CGFloat = 0.33 // low-pass factor per frame

    // Shooting
    static let projectileSpeed: CGFloat = 1000
    static let shootPoseTime: TimeInterval = 0.5
    static let shootCooldown: TimeInterval = 0.1
    /// Widest angle from straight up when directional shooting is on.
    static let maxShootAngle: CGFloat = 1.22       // radians ≈ 70°

    // Platforms
    static let platformSize = CGSize(width: 57, height: 15)
    static let verticalPlatformRange: CGFloat = 60
    /// Exploding platforms: yellow for this long after entering the view,
    /// then red for the same again, then the boom.
    static let explodingRedDelay: TimeInterval = 1.5
    static let explodingBoomDelay: TimeInterval = 1.5

    // Hazards
    static let ufoDriftSpeed: CGFloat = 24
    static let blackHolePullRadius: CGFloat = 80
    static let blackHoleCaptureRadius: CGFloat = 55

    // Fairness rule from the classic HUD: five pauses per game.
    static let pausesPerGame = 5

    // Score: one point per point of altitude, exactly like the original's
    // 320x480 space.
    static let scorePerPoint: CGFloat = 1.0
}
