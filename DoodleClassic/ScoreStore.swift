import Foundation

/// Local top-10 leaderboard, kept in UserDefaults the way the era's games
/// kept theirs: on-device, nothing leaves the phone.
///
/// This is a single-player cabinet, so runs are not signed with a name.
/// Older saves stored a `name` alongside the score; because Codable ignores
/// unknown keys, those entries still decode cleanly and keep their scores.
struct ScoreEntry: Codable, Equatable {
    let score: Int
}

enum ScoreStore {

    private static let scoresKey = "highScores"

    static var entries: [ScoreEntry] {
        guard let data = UserDefaults.standard.data(forKey: scoresKey),
              let list = try? JSONDecoder().decode([ScoreEntry].self, from: data)
        else { return [] }
        return list
    }

    static var best: ScoreEntry? { entries.first }

    /// Inserts a run into the board. Returns the 1-based rank if it made
    /// the top ten, else nil.
    @discardableResult
    static func submit(score: Int) -> Int? {
        var list = entries
        list.append(ScoreEntry(score: score))
        list.sort { $0.score > $1.score }
        if list.count > 10 { list = Array(list.prefix(10)) }
        if let data = try? JSONEncoder().encode(list) {
            UserDefaults.standard.set(data, forKey: scoresKey)
        }
        guard let rank = list.firstIndex(of: ScoreEntry(score: score))
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
