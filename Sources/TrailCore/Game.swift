import Foundation

public enum PlayMode:String,Codable,CaseIterable,Identifiable,Sendable {
    case solo,coop
    case legacyVersus="versus"
    public static let allCases:[PlayMode]=[.solo,.coop]
    public var id:String {rawValue}
    public var title:String {self == .coop ? "Co-op":"Solo"}
}
public enum MoveError:String,Error,LocalizedError,Sendable {
    case finished="This trail is complete. Start another adventure."
    case length="Keep the same number of letters."
    case letters="Use letters A–Z only."
    case unchanged="Change exactly one letter."
    case unknown="That word isn’t in the Word Trails dictionary."
    case repeated="You’ve visited that word. Undo a step to try a new route."
    case deadEnd="That step would leave no route to the goal without repeating a word. Try another word."
    public var errorDescription:String? {rawValue}
}
public struct Run:Codable,Hashable,Identifiable,Sendable {
    public let id:UUID
    public let puzzle:Puzzle
    public let mode:PlayMode
    // Decoding-only compatibility with saved games from the first beta.
    public let guide:String?
    public var chain:[String]
    public var hints=0
    public var totalMoves=0
    public var startedAt:Date
    public var finishedAt:Date?
    public var isDaily:Bool
    public var isComplete:Bool {chain.last == puzzle.goal}
    public var moves:Int {chain.count-1}
    public var scoreAgainstPar:Int {moves-puzzle.par}
    public var result:String {isComplete ? "Trail complete":"On the trail"}
    public var scoreDescription:String {
        let score=scoreAgainstPar
        return score == 0 ? "On par" : "\(abs(score)) \(score<0 ? "under":"over") par"
    }
    public init(puzzle:Puzzle,mode:PlayMode = .solo,daily:Bool=false,id:UUID=UUID()) {
        self.id=id;self.puzzle=puzzle;self.mode=mode == .legacyVersus ? .solo:mode
        guide=nil;chain=[puzzle.start];startedAt=Date();isDaily=daily
    }
    public mutating func submit(_ input:String,lexicon:Lexicon = .shared)throws {
        guard !isComplete else{throw MoveError.finished}
        let word=input.trimmingCharacters(in:.whitespacesAndNewlines).uppercased()
        guard word.count==puzzle.length else{throw MoveError.length}
        guard word.allSatisfy({$0.isASCII && $0.isLetter}) else{throw MoveError.letters}
        guard Lexicon.adjacent(chain.last!,word) else{throw MoveError.unchanged}
        guard lexicon.contains(word) else{throw MoveError.unknown}
        guard !chain.contains(word) else{throw MoveError.repeated}
        guard lexicon.path(from:word,to:puzzle.goal,avoiding:Set(chain)) != nil else{throw MoveError.deadEnd}
        chain.append(word);totalMoves+=1
        if isComplete{finishedAt=Date()}
    }
    public mutating func undo(){guard chain.count>1,!isComplete else{return};chain.removeLast()}
    public func hintSuggestion(lexicon:Lexicon = .shared,familiar:Lexicon = .familiar)->HintSuggestion? {
        let avoid=Set(chain.dropLast())
        guard let shortest=lexicon.path(from:chain.last!,to:puzzle.goal,avoiding:avoid),shortest.count>1 else{return nil}
        // The current word may be unusual; only FUTURE steps must be familiar.
        if let common=lexicon.path(from:chain.last!,to:puzzle.goal,avoiding:avoid,allowed:familiar.words),common.count==shortest.count {
            return HintSuggestion(word:common[1],requiresUnfamiliarWords:false)
        }
        return HintSuggestion(word:shortest[1],requiresUnfamiliarWords:true)
    }
    public func nextHint(lexicon:Lexicon = .shared)->String? {hintSuggestion(lexicon:lexicon)?.word}
    public func isValid(lexicon:Lexicon = .shared)->Bool {
        chain.first==puzzle.start && !chain.isEmpty && chain.count<=500 && Set(chain).count==chain.count && chain.allSatisfy{lexicon.contains($0)} && zip(chain,chain.dropFirst()).allSatisfy{Lexicon.adjacent($0,$1)} && (finishedAt==nil || isComplete)
    }
    public func migratedToSolo(recalculate:Bool)->Run {
        let shortest=recalculate ? (Lexicon.shared.path(from:puzzle.start,to:puzzle.goal)?.count ?? (puzzle.minimum+1))-1:puzzle.minimum
        let replacement=recalculate ? Puzzle(id:puzzle.id,start:puzzle.start,goal:puzzle.goal,par:shortest+TrailCatalog.parAllowance(length:puzzle.length),minimumSteps:shortest):puzzle
        var copy=Run(puzzle:replacement,daily:isDaily,id:id)
        copy.chain=chain;copy.hints=hints;copy.totalMoves=totalMoves;copy.startedAt=startedAt;copy.finishedAt=finishedAt
        return copy
    }
}
public struct HintSuggestion:Equatable,Sendable {
    public let word:String
    public let requiresUnfamiliarWords:Bool
}
public struct DifficultyStatistics:Sendable {
    public let attempted:Int,completed:Int,underPar:Int,onPar:Int,overPar:Int,shortestRoutes:Int
    public let averageMoves:Double?,averageAgainstPar:Double?,bestAgainstPar:Int?
    public var completionRate:Double {attempted==0 ? 0:Double(completed)/Double(attempted)}
    public init(attempts:[Run],completed:[Run],length:Int?=nil) {
        let starts=attempts.filter{length==nil || $0.puzzle.length==length}
        let finishes=completed.filter{length==nil || $0.puzzle.length==length}
        attempted=starts.count;self.completed=finishes.count
        underPar=finishes.filter{$0.scoreAgainstPar<0}.count
        onPar=finishes.filter{$0.scoreAgainstPar==0}.count
        overPar=finishes.filter{$0.scoreAgainstPar>0}.count
        shortestRoutes=finishes.filter{$0.moves==$0.puzzle.minimum}.count
        averageMoves=finishes.isEmpty ? nil:Double(finishes.reduce(0){$0+$1.moves})/Double(finishes.count)
        averageAgainstPar=finishes.isEmpty ? nil:Double(finishes.reduce(0){$0+$1.scoreAgainstPar})/Double(finishes.count)
        bestAgainstPar=finishes.map(\.scoreAgainstPar).min()
    }
}
public struct Badge:Identifiable,Sendable {
    public let id:String,title:String,detail:String,symbol:String
    public static let all:[Badge]=[
        Badge(id:"first",title:"First footsteps",detail:"Complete your first trail",symbol:"shoeprints.fill"),
        Badge(id:"perfect",title:"As the crow flies",detail:"Find a shortest route without hints or undo",symbol:"bird.fill"),
        Badge(id:"ten",title:"Trail regular",detail:"Complete 10 rewarded trails",symbol:"map.fill"),
        Badge(id:"fifty",title:"Pathfinder",detail:"Complete 50 rewarded trails",symbol:"signpost.right.fill"),
        Badge(id:"week",title:"Seven sunrises",detail:"Reach a 7-day daily streak",symbol:"sunrise.fill"),
        Badge(id:"month",title:"Habit in bloom",detail:"Reach a 30-day daily streak",symbol:"sun.max.fill"),
        Badge(id:"coop",title:"Better together",detail:"Finish a co-op trail",symbol:"person.2.fill"),
        Badge(id:"expert",title:"Mountain words",detail:"Complete a six-letter trail",symbol:"mountain.2.fill"),
        Badge(id:"hundred",title:"Well travelled",detail:"Complete 100 rewarded trails",symbol:"backpack.fill"),
        Badge(id:"quarter",title:"Across the map",detail:"Complete 250 rewarded trails",symbol:"globe.europe.africa.fill"),
        Badge(id:"fivehundred",title:"Far horizons",detail:"Complete 500 rewarded trails",symbol:"binoculars.fill"),
        Badge(id:"thousand",title:"A thousand paths",detail:"Complete 1,000 rewarded trails",symbol:"sparkles"),
        Badge(id:"daily30",title:"A month of walks",detail:"Play daily trails on 30 different days",symbol:"calendar"),
        Badge(id:"daily100",title:"A hundred mornings",detail:"Play daily trails on 100 different days",symbol:"sun.horizon.fill"),
        Badge(id:"daily365",title:"A year of wordplay",detail:"Play daily trails on 365 different days",symbol:"calendar.badge.checkmark"),
        Badge(id:"season",title:"Seasoned walker",detail:"Reach a 90-day daily streak",symbol:"leaf.circle.fill"),
        Badge(id:"year",title:"Every sunrise",detail:"Reach a 365-day daily streak",symbol:"sun.max.circle.fill"),
        Badge(id:"under25",title:"Ahead of the trail",detail:"Finish 25 different trails below par",symbol:"arrow.down.right"),
        Badge(id:"under100",title:"Below and beyond",detail:"Finish 100 different trails below par",symbol:"medal.fill"),
        Badge(id:"perfect25",title:"Direct routes",detail:"Find 25 different shortest routes without hints or undo",symbol:"point.topleft.down.to.point.bottomright.curvepath"),
        Badge(id:"perfect100",title:"A sure-footed hundred",detail:"Find 100 different shortest routes without hints or undo",symbol:"rosette"),
        Badge(id:"allLengths",title:"Every landscape",detail:"Complete 25 different trails at each word length",symbol:"mountain.2.circle.fill"),
        Badge(id:"garden",title:"In full bloom",detail:"Plant all six plants in your garden",symbol:"camera.macro"),
        Badge(id:"coop25",title:"Walking companions",detail:"Complete 25 different co-op trails",symbol:"person.2.circle.fill")
    ]
}
public struct Progress:Codable,Sendable {
    public var completed:[Run]=[]
    public var attempts:[Run]=[]
    public var claimed:Set<String> = []
    public var dailyDays:Set<String> = []
    public var seeds=0
    public var planted:Set<String> = []
    public var badges:Set<String> = []
    public var sharedGardens:[SharedGarden]=[]
    public var trackingStartedAt:Date?
    public init(){}
    enum CodingKeys:String,CodingKey {case completed,attempts,claimed,dailyDays,seeds,planted,badges,sharedGardens,trackingStartedAt}
    public init(from decoder:Decoder)throws {
        let c=try decoder.container(keyedBy:CodingKeys.self)
        completed=try c.decodeIfPresent([Run].self,forKey:.completed) ?? []
        attempts=try c.decodeIfPresent([Run].self,forKey:.attempts) ?? completed
        claimed=try c.decodeIfPresent(Set<String>.self,forKey:.claimed) ?? []
        dailyDays=try c.decodeIfPresent(Set<String>.self,forKey:.dailyDays) ?? []
        seeds=try c.decodeIfPresent(Int.self,forKey:.seeds) ?? 0
        planted=try c.decodeIfPresent(Set<String>.self,forKey:.planted) ?? []
        badges=try c.decodeIfPresent(Set<String>.self,forKey:.badges) ?? []
        sharedGardens=try c.decodeIfPresent([SharedGarden].self,forKey:.sharedGardens) ?? []
        trackingStartedAt=try c.decodeIfPresent(Date.self,forKey:.trackingStartedAt)
    }
    public mutating func migrateLegacyHistory(){
        completed=completed.map{($0.guide != nil || $0.mode == .legacyVersus) ? $0.migratedToSolo(recalculate:false):$0}
        attempts=attempts.map{($0.guide != nil || $0.mode == .legacyVersus) ? $0.migratedToSolo(recalculate:false):$0}
        sharedGardens.removeAll{$0.id.hasPrefix("bot-")};badges.remove("versus")
        if trackingStartedAt==nil{trackingStartedAt=Date()}
        for run in completed{track(run)}
    }
    public mutating func track(_ run:Run){
        if let i=attempts.firstIndex(where:{$0.id==run.id}){attempts[i]=run}else{attempts.append(run)}
    }
    public func statistics(length:Int?=nil)->DifficultyStatistics {DifficultyStatistics(attempts:attempts,completed:completed,length:length)}
    public var streak:Int {streak(at:Date())}
    public func streak(at date:Date)->Int {
        var cursor=Int(date.timeIntervalSince1970/86400)
        if !dailyDays.contains(TrailCatalog.dayKey(Date(timeIntervalSince1970:Double(cursor)*86400))){cursor-=1}
        var count=0
        while dailyDays.contains(TrailCatalog.dayKey(Date(timeIntervalSince1970:Double(cursor)*86400))){count+=1;cursor-=1}
        return count
    }
    @discardableResult public mutating func record(_ run:Run)->Int {
        guard run.isComplete,run.isValid(),!completed.contains(where:{$0.id==run.id}) else{return 0}
        track(run);completed.append(run)
        let fresh=claimed.insert("\(run.puzzle.id)-\(run.mode.rawValue)").inserted
        let earned=fresh ? 3+(run.moves<=run.puzzle.par && run.hints==0 ? 2:0):0
        seeds+=earned
        if run.isDaily,fresh,let finish=run.finishedAt{
            let day=TrailCatalog.dayKey(finish)
            if run.puzzle.id=="daily-\(day)-\(run.puzzle.length)"{dailyDays.insert(day)}
        }
        refreshBadges()
        return earned
    }
    public var longestDailyStreak:Int {
        var calendar=Calendar(identifier:.gregorian);calendar.timeZone=TimeZone(secondsFromGMT:0)!
        let days=dailyDays.compactMap { key->Int? in
            let parts=key.split(separator:"-").compactMap{Int($0)}
            guard parts.count==3,let date=calendar.date(from:DateComponents(year:parts[0],month:parts[1],day:parts[2])) else{return nil}
            return Int(date.timeIntervalSince1970/86400)
        }.sorted()
        var best=0,current=0,previous:Int?
        for day in days{current = previous==day-1 ? current+1:1;best=max(best,current);previous=day}
        return best
    }
    public mutating func refreshBadges(){
        func key(_ run:Run)->String {"\(run.puzzle.id)-\(run.mode.rawValue)"}
        let distinct=Dictionary(grouping:completed,by:key).values.compactMap{ $0.first }
        let perfect=Set(completed.filter{$0.moves==$0.puzzle.minimum && $0.hints==0 && $0.totalMoves==$0.moves}.map(key)).count
        let below=Set(completed.filter{$0.scoreAgainstPar<0}.map(key)).count
        let longest=longestDailyStreak
        if !completed.isEmpty{badges.insert("first")}
        if perfect>0{badges.insert("perfect")}
        for (amount,id) in [(10,"ten"),(50,"fifty"),(100,"hundred"),(250,"quarter"),(500,"fivehundred"),(1000,"thousand")] where claimed.count>=amount {badges.insert(id)}
        for (amount,id) in [(7,"week"),(30,"month"),(90,"season"),(365,"year")] where longest>=amount {badges.insert(id)}
        for (amount,id) in [(30,"daily30"),(100,"daily100"),(365,"daily365")] where dailyDays.count>=amount {badges.insert(id)}
        for (amount,id) in [(25,"under25"),(100,"under100")] where below>=amount {badges.insert(id)}
        for (amount,id) in [(25,"perfect25"),(100,"perfect100")] where perfect>=amount {badges.insert(id)}
        if distinct.contains(where:{$0.mode == .coop}){badges.insert("coop")}
        if distinct.filter({$0.mode == .coop}).count>=25{badges.insert("coop25")}
        if distinct.contains(where:{$0.puzzle.length==6}){badges.insert("expert")}
        if (3...6).allSatisfy({length in distinct.filter{$0.puzzle.length==length}.count>=25}){badges.insert("allLengths")}
        if Plant.all.allSatisfy({planted.contains($0.id)}){badges.insert("garden")}
    }
    public mutating func plant(_ id:String)->Bool {
        guard Plant.all.contains(where:{$0.id==id}),!planted.contains(id),seeds>=10 else{return false}
        seeds-=10;planted.insert(id);refreshBadges();return true
    }
    public mutating func rememberGarden(id:String,name:String,trailID:String){
        if let i=sharedGardens.firstIndex(where:{$0.id==id}){sharedGardens[i].completedTrails.insert(trailID);sharedGardens[i].name=name}
        else{sharedGardens.append(SharedGarden(id:id,name:name,completedTrails:[trailID]))}
    }
}
public struct SharedGarden:Codable,Identifiable,Sendable {
    public let id:String
    public var name:String
    public var completedTrails:Set<String>
    public var plants:Int {[1,3,5,8,12,20].filter{completedTrails.count >= $0}.count}
    public var nextMilestone:Int? {[1,3,5,8,12,20].first{$0>completedTrails.count}}
}
public struct Plant:Identifiable,Sendable {
    public let id:String,name:String,symbol:String
    public static let all=[Plant(id:"fern",name:"Fern",symbol:"leaf.fill"),Plant(id:"daisy",name:"Daisy",symbol:"sun.max.fill"),Plant(id:"oak",name:"Oak",symbol:"tree.fill"),Plant(id:"lavender",name:"Lavender",symbol:"camera.macro"),Plant(id:"pine",name:"Pine",symbol:"tree"),Plant(id:"clover",name:"Clover",symbol:"leaf.circle.fill")]
}
