#if DEBUG
import Foundation
import TrailCore

// Isolated simulator-only sample progress for reproducible store photography.
// All routes go through the same validation/reward code as a real game.
@MainActor extension TrailStore {
    func prepareStoreCapture() {
        guard ProcessInfo.processInfo.arguments.contains("--ui-test"),
              ProcessInfo.processInfo.arguments.contains("--store-capture") else{return}
        progress=TrailCore.Progress();showWelcome=false
        for offset in stride(from:12,through:1,by:-1) {
            let date=Date().addingTimeInterval(-Double(offset)*86400)
            let puzzle=TrailCatalog.daily(length:3+offset%4,date:date)
            var sample=Run(puzzle:puzzle,daily:true)
            for word in puzzle.familiarPath!.dropFirst(){try! sample.submit(word)}
            sample.startedAt=date.addingTimeInterval(-120);sample.finishedAt=date
            progress.record(sample)
        }
        for plant in Plant.all.prefix(3){_ = progress.plant(plant.id)}
        let args=ProcessInfo.processInfo.arguments
        let length=args.contains("--summit") ? 6:args.contains("--record-game") ? 3:4
        let preferred=length==6 ? "v2-CRATER-TRICKY":length==3 ? "v2-CON-PIE":"v2-HILL-SUNS"
        let puzzle=TrailCatalog.puzzles(length:length).first{$0.id==preferred}!
        var sample=Run(puzzle:puzzle)
        if !args.contains("--record-game") {
            let words=Array(puzzle.familiarPath!.dropFirst())
            for word in args.contains("--completed") ? words:Array(words.prefix(2)){try! sample.submit(word)}
        }
        run=sample
        if sample.isComplete{awarded=progress.record(sample)}else{progress.track(sample)}
        newBadges=[];message=""
    }
}
#endif
