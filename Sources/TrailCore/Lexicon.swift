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
    // Endpoints are authored; every route and par is verified against the shipped lexicon.
    static let pairs = [
        ("CAT","DOG"),("SUN","MAP"),("HAT","PIG"),("BED","CUP"),("BIG","HOT"),("PEN","BAG"),("RED","TOP"),("LOG","FIN"),
        ("COLD","WARM"),("HEAD","TAIL"),("LOVE","HATE"),("FISH","BIRD"),("DARK","LIME"),("FIRE","SNOW"),("FOOT","HAND"),("MOON","STAR"),
        ("STONE","SHARE"),("SHORE","PLATE"),("BRAIN","SPEAK"),("GRASS","GRAIN"),("LIGHT","SOUND"),("HEART","CROWN"),("SMILE","SPARE"),("BLACK","WHITE"),
        ("PLANET","PLATES"),("STREAM","SCREAM"),("STRING","STRONG"),("SINGER","FINGER"),("SHARED","SCARED"),("GARDEN","HARDEN"),("CARTED","MARTEN")
    ]
    public static let all: [Puzzle] = {
        let lex = Lexicon.shared
        var puzzles: [Puzzle] = []
        // Include authored endpoints when connected, plus a stable selection of longer routes.
        for (a,b) in pairs { if let path = lex.path(from: a, to: b), path.count > 2 { puzzles.append(Puzzle(id: "\(a)-\(b)", start: a, goal: b, par: path.count-1)) } }
        for length in 3...6 {
            let candidates = lex.words.filter { $0.count == length }.sorted()
            for (i, start) in candidates.enumerated() where i % 5 == 0 {
                for offset in [7,19,37] where !candidates.isEmpty {
                    let goal = candidates[(i+offset) % candidates.count]
                    if let route = lex.path(from: start, to: goal), (3...9).contains(route.count-1), !puzzles.contains(where: { $0.start == start && $0.goal == goal }) {
                        puzzles.append(Puzzle(id: "\(start)-\(goal)", start: start, goal: goal, par: route.count-1))
                    }
                }
                if puzzles.filter({$0.length == length}).count >= 60 { break }
            }
        }
        return puzzles.sorted { $0.id < $1.id }
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
