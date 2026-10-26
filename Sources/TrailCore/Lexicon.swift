import Foundation

public final class Lexicon: @unchecked Sendable {
    public static let shared = Lexicon()
    public let words: Set<String>
    private let buckets: [String: [String]]
    public init(words: Set<String>? = nil) {
        let source = words ?? Set((try? String(contentsOf: Bundle.module.url(forResource: "words", withExtension: "txt")!, encoding: .utf8))?.split(whereSeparator: \.isWhitespace).map { $0.uppercased() } ?? [])
        self.words = Set(source.filter { (3...6).contains($0.count) && $0.allSatisfy { $0.isASCII && $0.isLetter } })
        var index: [String: [String]] = [:]
        for word in self.words.sorted() {
            var letters = Array(word)
            for i in letters.indices { let old = letters[i]; letters[i] = "*"; index[String(letters), default: []].append(word); letters[i] = old }
        }
        buckets = index
    }
    public func contains(_ word: String) -> Bool { words.contains(word.uppercased()) }
    public static func adjacent(_ a: String, _ b: String) -> Bool {
        a.count == b.count && zip(a, b).filter { $0 != $1 }.count == 1
    }
    public func neighbors(_ word: String) -> [String] {
        var letters = Array(word), result = Set<String>()
        for i in letters.indices { let old = letters[i]; letters[i] = "*"; result.formUnion(buckets[String(letters)] ?? []); letters[i] = old }
        result.remove(word)
        return result.sorted()
    }
    public func path(from start: String, to goal: String, avoiding: Set<String> = []) -> [String]? {
        guard contains(start), contains(goal), start.count == goal.count else { return nil }
        if start == goal { return [start] }
        var queue = [start], head = 0, parent: [String: String] = [:], seen = avoiding
        seen.insert(start)
        while head < queue.count {
            let current = queue[head]; head += 1
            for next in neighbors(current) where !seen.contains(next) {
                seen.insert(next); parent[next] = current
                if next == goal {
                    var route = [goal], node = goal
                    while let prev = parent[node] { route.append(prev); node = prev }
                    return route.reversed()
                }
                queue.append(next)
            }
        }
        return nil
    }
}

public struct Puzzle: Codable, Hashable, Identifiable, Sendable {
    public let id: String
    public let start: String
    public let goal: String
    public let par: Int
    public var length: Int { start.count }
    public init(id: String, start: String, goal: String, par: Int) { self.id = id; self.start = start; self.goal = goal; self.par = par }
}

public enum TrailCatalog {
    // Built offline and independently checked against the lexicon by Swift tests.
    public static let all: [Puzzle] = {
        guard let url = Bundle.module.url(forResource:"trails",withExtension:"json"),
              let data = try? Data(contentsOf:url), let puzzles = try? JSONDecoder().decode([Puzzle].self,from:data),
              (3...6).allSatisfy({n in puzzles.contains {$0.length == n}}) else { preconditionFailure("Bundled trail catalog is missing or invalid") }
        return puzzles
    }()
    public static func dayKey(_ date: Date = Date()) -> String {
        let f = DateFormatter(); f.calendar = Calendar(identifier: .gregorian); f.locale = Locale(identifier: "en_US_POSIX"); f.timeZone = TimeZone(secondsFromGMT: 0); f.dateFormat = "yyyy-MM-dd"; return f.string(from: date)
    }
    public static func daily(length: Int, date: Date = Date()) -> Puzzle {
        let options = all.filter { $0.length == length }
        let day = Int(date.timeIntervalSince1970 / 86400)
        let base = options[((day % options.count) + options.count) % options.count]
        return Puzzle(id: "daily-\(dayKey(date))-\(length)", start: base.start, goal: base.goal, par: base.par)
    }
}
