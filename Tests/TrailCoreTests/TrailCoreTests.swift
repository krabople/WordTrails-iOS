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
    func testExpandedDictionaryAndPreviouslyRejectedSnares() throws {
        for word in ["SNARES","SNORES","SPARES","COLOUR","COLOR","HONOUR","HONOR"] { XCTAssertTrue(Lexicon.shared.contains(word),word) }
        XCTAssertGreaterThan(Lexicon.shared.words.count,37000)
        for word in ["CELLI","HASTED","BEDDER","ZAC"] {XCTAssertFalse(Lexicon.familiar.contains(word),word)}
        for word in ["OAF","JUT","FIB"] {XCTAssertTrue(Lexicon.familiar.contains(word),word)}
        var run=Run(puzzle:Puzzle(id:"regression",start:"SNORES",goal:"SPARES",par:3,minimumSteps:2))
        try run.submit("SNARES");try run.submit("SPARES")
        XCTAssertEqual(run.scoreAgainstPar,-1)
        XCTAssertFalse(TrailCatalog.puzzles(length:6).contains{Set([$0.start,$0.goal])==Set(["SNORES","SPARES"])})
    }
    func testAllFortyThousandTrailsHaveFamiliarOptimalRoutesAndGenerousPar() throws {
        XCTAssertEqual(TrailCatalog.all.count,40000)
        var pairs=Set<String>()
        for length in 3...6 { XCTAssertEqual(TrailCatalog.puzzles(length:length).count,10000) }
        for puzzle in TrailCatalog.all {
            XCTAssertTrue(pairs.insert([puzzle.start,puzzle.goal].sorted().joined(separator:"-")).inserted)
            let path=try XCTUnwrap(puzzle.familiarPath)
            XCTAssertEqual(path.first,puzzle.start);XCTAssertEqual(path.last,puzzle.goal)
            XCTAssertEqual(path.count-1,puzzle.minimum)
            XCTAssertGreaterThanOrEqual(puzzle.minimum,TrailCatalog.minimumDifficulty(length:puzzle.length))
            XCTAssertEqual(puzzle.par,puzzle.minimum+TrailCatalog.parAllowance(length:puzzle.length))
            XCTAssertTrue(path.allSatisfy{Lexicon.familiar.contains($0) && Lexicon.shared.contains($0)})
            XCTAssertTrue(zip(path,path.dropFirst()).allSatisfy{Lexicon.adjacent($0,$1)})
        }
        // Independent breadth-first search checks every target against the full dictionary.
        for (start,puzzles) in Dictionary(grouping:TrailCatalog.all,by: \.start) {
            let distances=Lexicon.shared.distances(from:start,maximum:10)
            for puzzle in puzzles { XCTAssertEqual(distances[puzzle.goal],puzzle.minimum,puzzle.id) }
        }
    }
    func testStatisticsTrackAttemptsAndEachParOutcomeByDifficulty() throws {
        var progress=TrailCore.Progress()
        for (index,par) in [4,3,2].enumerated() {
            var run=Run(puzzle:Puzzle(id:"stats-\(index)",start:"CAT",goal:"DOG",par:par,minimumSteps:3))
            progress.track(run);progress.track(run)
            for word in ["COT","DOT","DOG"] {try run.submit(word)}
            progress.record(run);progress.record(run)
        }
        progress.track(Run(puzzle:Puzzle(id:"unfinished",start:"CAT",goal:"DOG",par:4,minimumSteps:3)))
        progress.track(Run(puzzle:Puzzle(id:"other",start:"COLD",goal:"WARM",par:6,minimumSteps:5)))
        let stats=progress.statistics(length:3)
        XCTAssertEqual(stats.attempted,4);XCTAssertEqual(stats.completed,3)
        XCTAssertEqual(stats.underPar,1);XCTAssertEqual(stats.onPar,1);XCTAssertEqual(stats.overPar,1)
        XCTAssertEqual(stats.shortestRoutes,3);XCTAssertEqual(stats.completionRate,0.75)
        XCTAssertEqual(stats.averageMoves,3);XCTAssertEqual(stats.averageAgainstPar,0);XCTAssertEqual(stats.bestAgainstPar,-1)
        XCTAssertEqual(progress.statistics(length:4).attempted,1)
        XCTAssertEqual(progress.statistics(length:6).completed,0)
    }
    func testLegacySaveMigrationPreservesEarnedProgress() throws {
        var run=Run(puzzle:Puzzle(id:"old",start:"CAT",goal:"DOG",par:3))
        for word in ["COT","DOT","DOG"] {try run.submit(word)}
        var progress=TrailCore.Progress();progress.record(run);progress.seeds=25;progress.planted=["fern"]
        var json=try XCTUnwrap(JSONSerialization.jsonObject(with:JSONEncoder().encode(progress)) as? [String:Any])
        json.removeValue(forKey:"attempts");json.removeValue(forKey:"trackingStartedAt")
        var completed=try XCTUnwrap(json["completed"] as? [[String:Any]])
        completed[0]["mode"]="versus";completed[0]["guide"]="oak";json["completed"]=completed
        var restored=try JSONDecoder().decode(TrailCore.Progress.self,from:JSONSerialization.data(withJSONObject:json))
        restored.migrateLegacyHistory()
        XCTAssertEqual(restored.seeds,25);XCTAssertEqual(restored.planted,["fern"])
        XCTAssertEqual(restored.completed.first?.mode,.solo);XCTAssertNil(restored.completed.first?.guide)
        XCTAssertEqual(restored.completed.first?.puzzle.par,3);XCTAssertEqual(restored.attempts.count,1)
        XCTAssertEqual(restored.completed.first?.chain,run.chain)
        XCTAssertEqual(PlayMode.allCases,[.solo,.coop])
        XCTAssertEqual(try JSONDecoder().decode(TrailCore.Progress.self,from:JSONEncoder().encode(restored)).seeds,25)
    }
    func testCoopPacketsVersioningAndLegacyDictionaryCompatibility() throws {
        var packet=SharedTrail(puzzle:TrailCatalog.all[0]);try packet.validate()
        packet.version=99;XCTAssertThrowsError(try packet.validate())
        var old=SharedTrail(puzzle:TrailCatalog.legacy[0]);old.version=1;try old.validate()
        XCTAssertTrue(old.lexicon === Lexicon.legacy)
        old.mode = .legacyVersus;XCTAssertThrowsError(try old.validate())
    }
    func testReminderTimeValidationAndNextLocalOccurrence() throws {
        XCTAssertNil(ReminderTime(hour:24,minute:0));XCTAssertNil(ReminderTime(hour:1,minute:60))
        let time=try XCTUnwrap(ReminderTime(hour:19,minute:15))
        var calendar=Calendar(identifier:.gregorian);calendar.timeZone=TimeZone(secondsFromGMT:0)!
        let before=calendar.date(from:DateComponents(year:2026,month:10,day:26,hour:18))!
        let first=try XCTUnwrap(time.nextDate(after:before,calendar:calendar))
        XCTAssertEqual(calendar.component(.hour,from:first),19);XCTAssertEqual(calendar.component(.minute,from:first),15)
        let next=try XCTUnwrap(time.nextDate(after:first,calendar:calendar))
        XCTAssertEqual(next.timeIntervalSince(first),86400)
    }
    func testHintCanLeaveUnfamiliarWordViaFamiliarShortestRoute() throws {
        let all=Lexicon(words:["MAS","AAS","AAB","JAB","GAS","GAB"])
        let common=Lexicon(words:["GAS","GAB","JAB"])
        let run=Run(puzzle:Puzzle(id:"hint",start:"MAS",goal:"JAB",par:4,minimumSteps:3))
        XCTAssertEqual(all.path(from:"MAS",to:"JAB")?.dropFirst().first,"AAS")
        XCTAssertNil(common.path(from:"MAS",to:"JAB"))
        let hint=try XCTUnwrap(run.hintSuggestion(lexicon:all,familiar:common))
        XCTAssertEqual(hint.word,"GAS");XCTAssertFalse(hint.requiresUnfamiliarWords)
    }
    func testUnusualHintOnlyWhenNoFamiliarShortestContinuationRemains() throws {
        let all=Lexicon(words:["MEN","MAN","MAS","AAS","AAB","JAB","CAN","CAB"])
        let common=Lexicon(words:["MEN","MAN","CAN","CAB","JAB"])
        var run=Run(puzzle:Puzzle(id:"hint",start:"MEN",goal:"JAB",par:5,minimumSteps:4))
        XCTAssertFalse(try XCTUnwrap(run.hintSuggestion(lexicon:all,familiar:common)).requiresUnfamiliarWords)
        try run.submit("MAN",lexicon:all);try run.submit("MAS",lexicon:all)
        let hint=try XCTUnwrap(run.hintSuggestion(lexicon:all,familiar:common))
        XCTAssertEqual(hint.word,"AAS");XCTAssertTrue(hint.requiresUnfamiliarWords)
    }
    func testTodaysDailyHintsStayFamiliarAndAasIsNeverIntended() throws {
        XCTAssertFalse(Lexicon.familiar.contains("AAS"));XCTAssertTrue(Lexicon.shared.contains("AAS"))
        XCTAssertFalse(TrailCatalog.all.contains{($0.familiarPath ?? []).contains("AAS")})
        var run=Run(puzzle:TrailCatalog.daily(length:3,date:Date(timeIntervalSince1970:1792972800)))
        while !run.isComplete {
            let hint=try XCTUnwrap(run.hintSuggestion())
            XCTAssertFalse(hint.requiresUnfamiliarWords);XCTAssertTrue(Lexicon.familiar.contains(hint.word))
            try run.submit(hint.word)
        }
        XCTAssertEqual(run.moves,run.puzzle.minimum)
    }
    func testSameDailyPuzzleAcrossTimeZonesAndUtcRollover() throws {
        let iso=ISO8601DateFormatter()
        let london=try XCTUnwrap(iso.date(from:"2026-10-26T13:00:00+00:00"))
        let california=try XCTUnwrap(iso.date(from:"2026-10-26T06:00:00-07:00"))
        for length in 3...6 {
            XCTAssertEqual(TrailCatalog.daily(length:length,date:london),TrailCatalog.daily(length:length,date:california))
            let last=try XCTUnwrap(iso.date(from:"2026-10-26T23:59:59Z"))
            let first=last.addingTimeInterval(1)
            XCTAssertNotEqual(TrailCatalog.daily(length:length,date:last).id,TrailCatalog.daily(length:length,date:first).id)
        }
    }
    func testLongTermBadgesAndHistoricStreaksAreRecognised() {
        var progress=TrailCore.Progress()
        progress.claimed=Set((0..<1000).map{"trail-\($0)-solo"})
        let first=Date(timeIntervalSince1970:1704067200)
        progress.dailyDays=Set((0..<365).map{TrailCatalog.dayKey(first.addingTimeInterval(Double($0)*86400))})
        progress.planted=Set(Plant.all.map(\.id));progress.refreshBadges()
        XCTAssertEqual(progress.longestDailyStreak,365)
        for id in ["hundred","quarter","fivehundred","thousand","daily30","daily100","daily365","season","year","garden"] {XCTAssertTrue(progress.badges.contains(id),id)}
        XCTAssertEqual(Badge.all.count,24);XCTAssertEqual(Set(Badge.all.map(\.id)).count,24)
    }
    func testReplayingOnePuzzleCannotFarmDistinctRouteBadges() {
        var progress=TrailCore.Progress()
        for index in 0..<100 {
            var run=Run(puzzle:Puzzle(id:"same",start:"CAT",goal:"DOG",par:4,minimumSteps:3))
            run.chain=["CAT","COT","DOT","DOG"];run.totalMoves=3;run.finishedAt=Date()
            progress.completed.append(run)
            if index==99{progress.refreshBadges()}
        }
        XCTAssertFalse(progress.badges.contains("under25"));XCTAssertFalse(progress.badges.contains("perfect25"))
        progress.completed=[]
        for index in 0..<100 {
            var run=Run(puzzle:Puzzle(id:"different-\(index)",start:"CAT",goal:"DOG",par:4,minimumSteps:3))
            run.chain=["CAT","COT","DOT","DOG"];run.totalMoves=3;run.finishedAt=Date();progress.completed.append(run)
        }
        progress.refreshBadges()
        XCTAssertTrue(progress.badges.contains("under100"));XCTAssertTrue(progress.badges.contains("perfect100"))
    }
    func testDailyDeterminismUTCAndLengths() {
        let date = Date(timeIntervalSince1970:1793030400)
        for length in 3...6 { let a = TrailCatalog.daily(length:length,date:date); XCTAssertEqual(a,TrailCatalog.daily(length:length,date:date.addingTimeInterval(100))); XCTAssertEqual(a.length,length); XCTAssertTrue(a.id.contains(TrailCatalog.dayKey(date))) }
    }
    func testRewardsCannotBeClaimedTwiceAndGardenSpend() throws {
        var run = Run(puzzle:Puzzle(id:"reward",start:"CAT",goal:"DOG",par:3))
        for word in ["COT","DOT","DOG"] { try run.submit(word) }
        var progress = TrailCore.Progress(); XCTAssertEqual(progress.record(run),5); XCTAssertEqual(progress.record(run),0)
        var replay = Run(puzzle:run.puzzle); for word in ["COT","DOT","DOG"] { try replay.submit(word) }
        XCTAssertEqual(progress.record(replay),0); XCTAssertEqual(progress.seeds,5)
        XCTAssertTrue(progress.badges.contains("first")); XCTAssertTrue(progress.badges.contains("perfect"))
        XCTAssertFalse(progress.plant("fern")); progress.seeds = 20
        XCTAssertTrue(progress.plant("fern")); XCTAssertFalse(progress.plant("fern")); XCTAssertFalse(progress.plant("unknown")); XCTAssertEqual(progress.seeds,10)
    }
    func testInvalidRunsCannotEarnRewards() {
        var run = Run(puzzle:Puzzle(id:"fake",start:"CAT",goal:"DOG",par:1)); run.chain = ["CAT","DOG"]; run.finishedAt = Date()
        var progress = TrailCore.Progress(); XCTAssertEqual(progress.record(run),0)
    }
    func testHintsAvoidVisitedWordsAndRoundTrip() throws {
        var run = Run(puzzle:Puzzle(id:"test",start:"CAT",goal:"DOG",par:3))
        while !run.isComplete { let next = try XCTUnwrap(run.nextHint()); try run.submit(next) }
        XCTAssertEqual(run.moves,3)
        XCTAssertEqual(try JSONDecoder().decode(Run.self,from:JSONEncoder().encode(run)),run)
    }
    func testStreakIncludesYesterdayButDoesNotExtendAcrossGap() {
        let today = Date(timeIntervalSince1970:1793030400)
        var progress = TrailCore.Progress()
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
        var progress = TrailCore.Progress()
        for _ in 0..<3 { progress.rememberGarden(id:"friend",name:"Friend",trailID:"same") }
        XCTAssertEqual(progress.sharedGardens.first?.completedTrails.count,1)
        XCTAssertEqual(progress.sharedGardens.first?.plants,1)
        progress.rememberGarden(id:"friend",name:"Friend",trailID:"second")
        progress.rememberGarden(id:"friend",name:"Friend",trailID:"third")
        XCTAssertEqual(progress.sharedGardens.first?.plants,2)
        XCTAssertEqual(progress.sharedGardens.first?.nextMilestone,5)
    }
}
