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
    public func nextHint(lexicon:Lexicon = .shared)->String? {
        let avoid=Set(chain.dropLast())
        guard let shortest=lexicon.path(from:chain.last!,to:puzzle.goal,avoiding:avoid) else{return nil}
        if lexicon === Lexicon.shared,let familiar=Lexicon.familiar.path(from:chain.last!,to:puzzle.goal,avoiding:avoid),familiar.count==shortest.count{return familiar.dropFirst().first}
        return shortest.dropFirst().first
    }
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
        Badge(id:"expert",title:"Mountain words",detail:"Complete a six-letter trail",symbol:"mountain.2.fill")
    ]
}
public struct Progress:Codable,Sendable {
    public var completed:[Run]=[]
    public var attempts:[Run]=[]
    public var claimed:Set<String> =[]
    public var dailyDays:Set<String> =[]
    public var seeds=0
    public var planted:Set<String> =[]
    public var badges:Set<String> =[]
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
        badges.insert("first")
        if run.moves==run.puzzle.minimum && run.hints==0 && run.totalMoves==run.moves{badges.insert("perfect")}
        if claimed.count>=10{badges.insert("ten")};if claimed.count>=50{badges.insert("fifty")}
        if streak>=7{badges.insert("week")};if streak>=30{badges.insert("month")}
        if run.mode == .coop{badges.insert("coop")}
        if run.puzzle.length==6{badges.insert("expert")}
        return earned
    }
    public mutating func plant(_ id:String)->Bool {
        guard Plant.all.contains(where:{$0.id==id}),!planted.contains(id),seeds>=10 else{return false}
        seeds-=10;planted.insert(id);return true
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
