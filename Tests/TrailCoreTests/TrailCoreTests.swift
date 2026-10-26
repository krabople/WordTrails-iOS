import XCTest
@testable import TrailCore

final class TrailCoreTests: XCTestCase {
    func testOneLetterRuleAndRejectedInput() throws {
        var run = Run(puzzle:Puzzle(id:"test",start:"CAT",goal:"DOG",par:3))
        XCTAssertThrowsError(try run.submit("CAT"))
        XCTAssertThrowsError(try run.submit("DOG"))
        XCTAssertThrowsError(try run.submit("CATS"))
        XCTAssertThrowsError(try run.submit("C@T"))
        try run.submit(" cot "); try run.submit("DOT"); try run.submit("DOG")
        XCTAssertTrue(run.isComplete); XCTAssertEqual(run.moves,3); XCTAssertTrue(run.isValid())
        XCTAssertThrowsError(try run.submit("DOT"))
    }
    func testRepeatedWordAndUndo() throws {
        var run = Run(puzzle:Puzzle(id:"test",start:"CAT",goal:"DOG",par:3))
        try run.submit("COT"); XCTAssertThrowsError(try run.submit("CAT"))
        run.undo(); XCTAssertEqual(run.chain,["CAT"]); XCTAssertEqual(run.totalMoves,1)
    }
    func testEveryPuzzleIsSolvableAndParIsShortest() {
        XCTAssertGreaterThan(TrailCatalog.all.count,100)
        for length in 3...6 { XCTAssertGreaterThan(TrailCatalog.all.filter {$0.length == length}.count,5) }
        for puzzle in TrailCatalog.all {
            let path = Lexicon.shared.path(from:puzzle.start,to:puzzle.goal)!
            XCTAssertEqual(path.count-1,puzzle.par,puzzle.id)
            XCTAssertTrue(zip(path,path.dropFirst()).allSatisfy { Lexicon.adjacent($0,$1) })
        }
    }
    func testBotRoutesUseRealWordsWithoutRepeats() {
        for puzzle in TrailCatalog.all { for guide in Guide.allCases {
            let route = guide.route(for:puzzle)
            XCTAssertEqual(route.first,puzzle.start); XCTAssertEqual(route.last,puzzle.goal)
            XCTAssertEqual(Set(route).count,route.count)
            XCTAssertTrue(route.allSatisfy { Lexicon.shared.contains($0) })
            XCTAssertTrue(zip(route,route.dropFirst()).allSatisfy { Lexicon.adjacent($0,$1) })
            if guide == .oak { XCTAssertEqual(route.count-1,puzzle.par) }
        } }
    }
    func testDailyDeterminismUTCAndLengths() {
        let date = Date(timeIntervalSince1970:1793030400)
        for length in 3...6 { let a = TrailCatalog.daily(length:length,date:date); XCTAssertEqual(a,TrailCatalog.daily(length:length,date:date.addingTimeInterval(100))); XCTAssertEqual(a.length,length); XCTAssertTrue(a.id.contains(TrailCatalog.dayKey(date))) }
    }
    func testRewardsCannotBeClaimedTwiceAndGardenSpend() throws {
        var run = Run(puzzle:Puzzle(id:"reward",start:"CAT",goal:"DOG",par:3))
        for word in ["COT","DOT","DOG"] { try run.submit(word) }
        var progress = Progress(); XCTAssertEqual(progress.record(run),5); XCTAssertEqual(progress.record(run),0)
        var replay = Run(puzzle:run.puzzle); for word in ["COT","DOT","DOG"] { try replay.submit(word) }
        XCTAssertEqual(progress.record(replay),0); XCTAssertEqual(progress.seeds,5)
        XCTAssertTrue(progress.badges.contains("first")); XCTAssertTrue(progress.badges.contains("perfect"))
        XCTAssertFalse(progress.plant("fern")); progress.seeds = 20
        XCTAssertTrue(progress.plant("fern")); XCTAssertFalse(progress.plant("fern")); XCTAssertFalse(progress.plant("unknown")); XCTAssertEqual(progress.seeds,10)
    }
    func testInvalidRunsCannotEarnRewards() {
        var run = Run(puzzle:Puzzle(id:"fake",start:"CAT",goal:"DOG",par:1)); run.chain = ["CAT","DOG"]; run.finishedAt = Date()
        var progress = Progress(); XCTAssertEqual(progress.record(run),0)
    }
    func testHintsAvoidVisitedWordsAndRoundTrip() throws {
        var run = Run(puzzle:Puzzle(id:"test",start:"CAT",goal:"DOG",par:3))
        while !run.isComplete { let next = try XCTUnwrap(run.nextHint()); try run.submit(next) }
        XCTAssertEqual(run.moves,3)
        XCTAssertEqual(try JSONDecoder().decode(Run.self,from:JSONEncoder().encode(run)),run)
    }
    func testStreakIncludesYesterdayButDoesNotExtendAcrossGap() {
        let today = Date(timeIntervalSince1970:1793030400)
        var progress = Progress()
        for offset in 1...7 { progress.dailyDays.insert(TrailCatalog.dayKey(today.addingTimeInterval(Double(-offset)*86400))) }
        XCTAssertEqual(progress.streak(at:today),7)
        XCTAssertEqual(progress.streak(at:today.addingTimeInterval(86400)),0)
    }
    func testMoveCannotTrapPlayer() throws {
        let lex = Lexicon(words:["CAT","COT","DOT","DOG","BAT"])
        var run = Run(puzzle:Puzzle(id:"trap",start:"CAT",goal:"DOG",par:3))
        XCTAssertThrowsError(try run.submit("BAT",lexicon:lex)) { XCTAssertEqual($0 as? MoveError,.deadEnd) }
        XCTAssertEqual(run.chain,["CAT"])
        try run.submit("COT",lexicon:lex)
        XCTAssertNotNil(run.nextHint(lexicon:lex))
    }
    func testSharedGardenDoesNotDoubleCountSync() {
        var progress = Progress()
        for _ in 0..<3 { progress.rememberGarden(id:"friend",name:"Friend",trailID:"same") }
        XCTAssertEqual(progress.sharedGardens.first?.completedTrails.count,1)
        XCTAssertEqual(progress.sharedGardens.first?.plants,1)
        progress.rememberGarden(id:"friend",name:"Friend",trailID:"second")
        progress.rememberGarden(id:"friend",name:"Friend",trailID:"third")
        XCTAssertEqual(progress.sharedGardens.first?.plants,2)
        XCTAssertEqual(progress.sharedGardens.first?.nextMilestone,5)
    }
}
