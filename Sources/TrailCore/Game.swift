import Foundation

public enum PlayMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case solo, coop, versus
    public var id: String { rawValue }
    public var title: String { switch self { case .solo: "Solo"; case .coop: "Co-op"; case .versus: "Versus" } }
}
public enum Guide: String, Codable, CaseIterable, Identifiable, Sendable {
    case pip, fern, oak
    public var id: String { rawValue }
    public var name: String { rawValue.capitalized }
    public var caption: String { switch self { case .pip: "Gentle · takes the scenic route"; case .fern: "Thoughtful · a little challenge"; case .oak: "Expert · finds the shortest route" } }
    public var symbol: String { switch self { case .pip: "bird.fill"; case .fern: "leaf.fill"; case .oak: "tree.fill" } }
    public func route(for puzzle: Puzzle, lexicon: Lexicon = .shared) -> [String] {
        let shortest = lexicon.path(from: puzzle.start, to: puzzle.goal) ?? [puzzle.start]
        guard self != .oak else { return shortest }
        // A legal detour, never invented words or repeated nodes. Deterministic and auditable.
        let budget = self == .pip ? 5 : 2
        var best = shortest
        for neighbor in lexicon.neighbors(puzzle.start) where neighbor != shortest.dropFirst().first {
            if let tail = lexicon.path(from: neighbor, to: puzzle.goal, avoiding: [puzzle.start]) {
                let route = [puzzle.start] + tail
                if route.count > best.count && route.count <= shortest.count + budget { best = route }
            }
        }
        return best
    }
}
public enum MoveError: String, Error, LocalizedError, Sendable {
    case finished = "This trail is complete. Start another adventure."
    case length = "Keep the same number of letters."
    case letters = "Use letters A–Z only."
    case unchanged = "Change exactly one letter."
    case unknown = "That word isn’t in the Word Trails dictionary."
    case repeated = "You’ve visited that word. Undo a step to try a new route."
    public var errorDescription: String? { rawValue }
}
public struct Run: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public let puzzle: Puzzle
    public let mode: PlayMode
    public let guide: Guide?
    public var chain: [String]
    public var hints = 0
    public var totalMoves = 0
    public var startedAt: Date
    public var finishedAt: Date?
    public var isDaily: Bool
    public var isComplete: Bool { chain.last == puzzle.goal }
    public var moves: Int { chain.count - 1 }
    public var botMoves: Int? { guide.map { $0.route(for: puzzle).count - 1 } }
    public var result: String {
        guard isComplete else { return "On the trail" }
        guard mode == .versus, let botMoves else { return "Trail complete" }
        return moves < botMoves ? "You won!" : moves == botMoves ? "A shared summit" : "\(guide!.name) won"
    }
    public init(puzzle: Puzzle, mode: PlayMode = .solo, guide: Guide? = nil, daily: Bool = false, id: UUID = UUID()) {
        self.id = id; self.puzzle = puzzle; self.mode = mode; self.guide = guide; chain = [puzzle.start]; startedAt = Date(); isDaily = daily
    }
    public mutating func submit(_ input: String, lexicon: Lexicon = .shared) throws {
        guard !isComplete else { throw MoveError.finished }
        let word = input.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard word.count == puzzle.length else { throw MoveError.length }
        guard word.allSatisfy({ $0.isASCII && $0.isLetter }) else { throw MoveError.letters }
        guard Lexicon.adjacent(chain.last!, word) else { throw MoveError.unchanged }
        guard lexicon.contains(word) else { throw MoveError.unknown }
        guard !chain.contains(word) else { throw MoveError.repeated }
        chain.append(word); totalMoves += 1
        if isComplete { finishedAt = Date() }
    }
    public mutating func undo() {
        guard chain.count > 1, !isComplete else { return }
        chain.removeLast()
    }
    public func nextHint(lexicon: Lexicon = .shared) -> String? {
        lexicon.path(from: chain.last!, to: puzzle.goal, avoiding: Set(chain.dropLast()))?.dropFirst().first
    }
    public mutating func guideStep() throws {
        guard let hint = nextHint() else { return }
        try submit(hint)
    }
    public func isValid(lexicon: Lexicon = .shared) -> Bool {
        chain.first == puzzle.start && !chain.isEmpty && chain.count <= 500 && Set(chain).count == chain.count && chain.allSatisfy { lexicon.contains($0) } && zip(chain, chain.dropFirst()).allSatisfy { Lexicon.adjacent($0,$1) } && (finishedAt == nil || isComplete)
    }
}

public struct Badge: Identifiable, Sendable {
    public let id: String; public let title: String; public let detail: String; public let symbol: String
    public static let all: [Badge] = [
        Badge(id:"first",title:"First footsteps",detail:"Complete your first trail",symbol:"shoeprints.fill"),
        Badge(id:"perfect",title:"As the crow flies",detail:"Finish at par without hints or undo",symbol:"bird.fill"),
        Badge(id:"ten",title:"Trail regular",detail:"Complete 10 different trails",symbol:"map.fill"),
        Badge(id:"fifty",title:"Pathfinder",detail:"Complete 50 different trails",symbol:"signpost.right.fill"),
        Badge(id:"week",title:"Seven sunrises",detail:"Complete daily trails on 7 consecutive UTC days",symbol:"sunrise.fill"),
        Badge(id:"month",title:"Habit in bloom",detail:"Reach a 30-day daily streak",symbol:"sun.max.fill"),
        Badge(id:"coop",title:"Better together",detail:"Finish a co-op trail",symbol:"person.2.fill"),
        Badge(id:"versus",title:"Friendly rivalry",detail:"Win a versus trail",symbol:"flag.checkered"),
        Badge(id:"expert",title:"Mountain words",detail:"Complete a six-letter trail",symbol:"mountain.2.fill")
    ]
}
public struct Progress: Codable, Sendable {
    public var completed: [Run] = []
    public var claimed: Set<String> = []
    public var dailyDays: Set<String> = []
    public var seeds = 0
    public var planted: Set<String> = []
    public var badges: Set<String> = []
    public init() {}
    public var streak: Int { streak(at: Date()) }
    public func streak(at date: Date) -> Int {
        let day = Int(date.timeIntervalSince1970 / 86400)
        var cursor = day
        if !dailyDays.contains(TrailCatalog.dayKey(Date(timeIntervalSince1970: Double(cursor)*86400))) { cursor -= 1 }
        var count = 0
        while dailyDays.contains(TrailCatalog.dayKey(Date(timeIntervalSince1970: Double(cursor)*86400))) { count += 1; cursor -= 1 }
        return count
    }
    @discardableResult public mutating func record(_ run: Run) -> Int {
        guard run.isComplete, run.isValid(), !completed.contains(where: {$0.id == run.id}) else { return 0 }
        completed.append(run)
        let key = "\(run.puzzle.id)-\(run.mode.rawValue)"
        let fresh = claimed.insert(key).inserted
        let earned = fresh ? 3 + (run.moves == run.puzzle.par && run.hints == 0 ? 2 : 0) : 0
        seeds += earned
        if run.isDaily, fresh, let finish = run.finishedAt {
            let key = TrailCatalog.dayKey(finish)
            // A saved trail completed after its day still earns seeds, but cannot backdate a streak.
            if run.puzzle.id == "daily-\(key)-\(run.puzzle.length)" { dailyDays.insert(key) }
        }
        badges.insert("first")
        if run.moves == run.puzzle.par && run.hints == 0 && run.totalMoves == run.moves { badges.insert("perfect") }
        if claimed.count >= 10 { badges.insert("ten") }
        if claimed.count >= 50 { badges.insert("fifty") }
        if streak >= 7 { badges.insert("week") }
        if streak >= 30 { badges.insert("month") }
        if run.mode == .coop { badges.insert("coop") }
        if run.mode == .versus, let bot = run.botMoves, run.moves < bot { badges.insert("versus") }
        if run.puzzle.length == 6 { badges.insert("expert") }
        return earned
    }
    public mutating func plant(_ id: String) -> Bool {
        guard Plant.all.contains(where: {$0.id == id}), !planted.contains(id), seeds >= 10 else { return false }
        seeds -= 10; planted.insert(id); return true
    }
}
public struct Plant: Identifiable, Sendable {
    public let id: String; public let name: String; public let symbol: String
    public static let all = [Plant(id:"fern",name:"Fern",symbol:"leaf.fill"),Plant(id:"daisy",name:"Daisy",symbol:"sun.max.fill"),Plant(id:"oak",name:"Oak",symbol:"tree.fill"),Plant(id:"lavender",name:"Lavender",symbol:"camera.macro"),Plant(id:"pine",name:"Pine",symbol:"tree"),Plant(id:"clover",name:"Clover",symbol:"leaf.circle.fill")]
}
