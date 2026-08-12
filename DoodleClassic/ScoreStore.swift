import Foundation

/// Local top-10 leaderboard, kept in UserDefaults exactly like the era's
/// games kept theirs on-device: a name and a score, nothing leaves the phone.
struct ScoreEntry: Codable, Equatable {
    let name: String
    let score: Int
}

enum ScoreStore {

    private static let scoresKey = "highScores"
    private static let nameKey = "lastPlayerName"

    static var entries: [ScoreEntry] {
        guard let data = UserDefaults.standard.data(forKey: scoresKey),
              let list = try? JSONDecoder().decode([ScoreEntry].self, from: data)
        else { return [] }
        return list
    }

    static var best: ScoreEntry? { entries.first }

    static var lastPlayerName: String {
        get { UserDefaults.standard.string(forKey: nameKey) ?? "Doodler" }
        set { UserDefaults.standard.set(newValue, forKey: nameKey) }
    }

    /// Inserts a run into the board. Returns the 1-based rank if it made
    /// the top ten, else nil.
    @discardableResult
    static func submit(name: String, score: Int) -> Int? {
        var list = entries
        list.append(ScoreEntry(name: name, score: score))
        list.sort { $0.score > $1.score }
        if list.count > 10 { list = Array(list.prefix(10)) }
        if let data = try? JSONEncoder().encode(list) {
            UserDefaults.standard.set(data, forKey: scoresKey)
        }
        guard let rank = list.firstIndex(of: ScoreEntry(name: name, score: score))
        else { return nil }
        return rank + 1
    }

    /// True if this score would beat the current best.
    static func isNewBest(_ score: Int) -> Bool {
        score > (best?.score ?? 0)
    }

    /// Clear the whole board (the reset button on the scores screen).
    static func wipe() {
        UserDefaults.standard.removeObject(forKey: scoresKey)
    }
}
