import Foundation

public struct SharedTrail:Codable {
    public var version=2
    public var mode:PlayMode
    public var puzzle:Puzzle
    public var coop:Run
    public init(puzzle:Puzzle){self.puzzle=puzzle;mode = .coop;coop=Run(puzzle:puzzle,mode:.coop)}
    public var lexicon:Lexicon {version==1 ? .legacy:.shared}
    public func validate()throws {
        let known = version==1 ? TrailCatalog.legacy:TrailCatalog.all
        guard (version==1 || version==2),mode == .coop,
              known.contains(where:{$0.start==puzzle.start && $0.goal==puzzle.goal && $0.par==puzzle.par && $0.minimum==puzzle.minimum}),
              coop.puzzle==puzzle,coop.mode == .coop,coop.guide==nil,coop.hints==0,coop.isValid(lexicon:lexicon) else{throw SharedTrailError.invalid}
    }
}
public enum SharedTrailError:LocalizedError {
    case invalid
    public var errorDescription:String? {"This co-op trail uses incompatible game data. Both players should update Word Trails before starting a new trail."}
}
