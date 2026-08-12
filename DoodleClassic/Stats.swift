import Foundation

/// The classic stats screen tracked exactly these counters, all local.
enum Stats {

    private static let d = UserDefaults.standard

    static var gamesPlayed: Int {
        get { d.integer(forKey: "stat.games") }
        set { d.set(newValue, forKey: "stat.games") }
    }
    static var totalScore: Int {
        get { d.integer(forKey: "stat.totalScore") }
        set { d.set(newValue, forKey: "stat.totalScore") }
    }
    static var totalJumps: Int {
        get { d.integer(forKey: "stat.jumps") }
        set { d.set(newValue, forKey: "stat.jumps") }
    }
    static var jetpackFlights: Int {
        get { d.integer(forKey: "stat.jetpacks") }
        set { d.set(newValue, forKey: "stat.jetpacks") }
    }
    static var propellerFlights: Int {
        get { d.integer(forKey: "stat.propellers") }
        set { d.set(newValue, forKey: "stat.propellers") }
    }
    static var ufosShot: Int {
        get { d.integer(forKey: "stat.ufos") }
        set { d.set(newValue, forKey: "stat.ufos") }
    }

    static var averageScore: Int {
        gamesPlayed > 0 ? totalScore / gamesPlayed : 0
    }

    static func recordRun(score: Int) {
        gamesPlayed += 1
        totalScore += score
    }

    static func reset() {
        for key in ["stat.games", "stat.totalScore", "stat.jumps",
                    "stat.jetpacks", "stat.propellers", "stat.ufos"] {
            d.removeObject(forKey: key)
        }
    }
}
