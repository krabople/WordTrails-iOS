import Foundation

public final class Lexicon: @unchecked Sendable {
    public static let shared = Lexicon(resource:"words")
    public static let familiar = Lexicon(resource:"familiar-words")
    public static let legacy = Lexicon(resource:"legacy-words-v1")
    public let words: Set<String>
    public let sortedWords: [String]
    private let adjacency: [String:[String]]
    public convenience init(resource:String) {
        let url = Bundle.module.url(forResource:resource,withExtension:"txt")!
        self.init(words:Set((try! String(contentsOf:url,encoding:.utf8)).split(whereSeparator:\.isWhitespace).map(String.init)))
    }
    public init(words:Set<String>) {
        self.words = Set(words.map {$0.uppercased()}.filter {(3...6).contains($0.count) && $0.allSatisfy {$0.isASCII && $0.isLetter}})
        sortedWords = self.words.sorted()
        var buckets:[String:[String]] = [:]
        for word in sortedWords { var letters=Array(word); for i in letters.indices {let old=letters[i];letters[i]="*";buckets[String(letters),default:[]].append(word);letters[i]=old} }
        var graph:[String:[String]] = [:]
        for word in sortedWords { var letters=Array(word),edges:[String]=[];for i in letters.indices {let old=letters[i];letters[i]="*";edges.append(contentsOf:(buckets[String(letters)] ?? []).filter {$0 != word});letters[i]=old};graph[word]=edges.sorted() }
        adjacency=graph
    }
    public func contains(_ word:String)->Bool {words.contains(word.uppercased())}
    public static func adjacent(_ a:String,_ b:String)->Bool {a.count==b.count && zip(a,b).filter {$0 != $1}.count==1}
    public func neighbors(_ word:String)->[String] {adjacency[word] ?? []}
    public func path(from start:String,to goal:String,avoiding:Set<String> = [])->[String]? {
        guard contains(start),contains(goal),start.count==goal.count else{return nil}
        if start==goal{return[start]}
        var queue=[start],head=0,parent:[String:String]=[:],seen=avoiding;seen.insert(start)
        while head<queue.count {let current=queue[head];head+=1;for next in neighbors(current) where !seen.contains(next) {seen.insert(next);parent[next]=current;if next==goal {var route=[goal],node=goal;while let prev=parent[node] {route.append(prev);node=prev};return route.reversed()};queue.append(next)}}
        return nil
    }
    public func distances(from start:String,maximum:Int=Int.max)->[String:Int] {
        guard contains(start) else{return[:]}
        var queue=[start],head=0,dist=[start:0]
        while head<queue.count {let current=queue[head];head+=1;let depth=dist[current]!;if depth>=maximum{continue};for next in neighbors(current) where dist[next]==nil {dist[next]=depth+1;queue.append(next)}}
        return dist
    }
    public static var licence:String {["Dictionary-Licence","Familiar-Licence"].compactMap{resource in Bundle.module.url(forResource:resource,withExtension:"txt").flatMap{try? String(contentsOf:$0,encoding:.utf8)}}.joined(separator:"\n\n")}
}

public struct Puzzle: Codable,Hashable,Identifiable,Sendable {
    public let id:String
    public let start:String
    public let goal:String
    public let par:Int
    public let minimumSteps:Int?
    public let familiarPath:[String]?
    public var length:Int {start.count}
    public var minimum:Int {minimumSteps ?? par}
    public init(id:String,start:String,goal:String,par:Int,minimumSteps:Int?=nil,familiarPath:[String]?=nil) {
        self.id=id;self.start=start;self.goal=goal;self.par=par;self.minimumSteps=minimumSteps;self.familiarPath=familiarPath
    }
}
public enum TrailCatalog {
    public static let contentVersion=2
    public static let all:[Puzzle]=load("trails")
    public static let legacy:[Puzzle]=load("legacy-trails-v1")
    private static let grouped=Dictionary(grouping:all,by:\.length)
    private static func load(_ resource:String)->[Puzzle] {
        let data=try! Data(contentsOf:Bundle.module.url(forResource:resource,withExtension:"json")!)
        return try! JSONDecoder().decode([Puzzle].self,from:data)
    }
    public static func puzzles(length:Int)->[Puzzle] {grouped[length] ?? []}
    public static func minimumDifficulty(length:Int)->Int {length+1}
    public static func parAllowance(length:Int)->Int {length>=5 ? 2:1}
    public static func dayKey(_ date:Date=Date())->String {
        let f=DateFormatter();f.calendar=Calendar(identifier:.gregorian);f.locale=Locale(identifier:"en_US_POSIX");f.timeZone=TimeZone(secondsFromGMT:0);f.dateFormat="yyyy-MM-dd";return f.string(from:date)
    }
    public static func daily(length:Int,date:Date=Date())->Puzzle {
        let options=puzzles(length:length),day=Int(date.timeIntervalSince1970/86400)
        let base=options[((day%options.count)+options.count)%options.count]
        return Puzzle(id:"daily-\(dayKey(date))-\(length)",start:base.start,goal:base.goal,par:base.par,minimumSteps:base.minimum,familiarPath:base.familiarPath)
    }
}
