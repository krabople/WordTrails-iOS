import SwiftUI
import TrailCore

@MainActor final class TrailStore:ObservableObject {
    @Published var progress=TrailCore.Progress()
    @Published var run:Run?
    @Published var message=""
    @Published var awarded=0
    @Published var busy=false
    @Published var showWelcome = !UserDefaults.standard.bool(forKey:"welcomed")
    @Published var persistenceError:String?
    @Published var showRecoveryWarning=false
    private let url:URL
    init(){
        let directory=FileManager.default.urls(for:.applicationSupportDirectory,in:.userDomainMask)[0].appendingPathComponent("WordTrails",isDirectory:true)
        let testing=ProcessInfo.processInfo.arguments.contains("--ui-test")
        url=directory.appendingPathComponent(testing ? "uitest-\(UUID().uuidString).json":"progress-v1.json")
        if testing{showWelcome=true}
        do{
            try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true)
            if FileManager.default.fileExists(atPath:url.path){
                let saved=try JSONDecoder().decode(Saved.self,from:Data(contentsOf:url))
                progress=saved.progress;run=saved.run
            }
            progress.migrateLegacyHistory()
            if let old=run,old.puzzle.minimumSteps==nil || old.guide != nil || old.mode == .legacyVersus {
                run=old.migratedToSolo(recalculate:!old.isComplete)
                if !old.isComplete{message="Your saved trail now uses the expanded dictionary and updated par."}
            }
            if let run{progress.track(run)}
        }catch{persistenceError="Your saved progress couldn’t be opened. It has been kept on this device. \(error.localizedDescription)";showRecoveryWarning=true}
        #if DEBUG
        if testing && ProcessInfo.processInfo.arguments.contains("--example-trail"){
            run=Run(puzzle:Puzzle(id:"example-CAT-DOG",start:"CAT",goal:"DOG",par:4,minimumSteps:3))
            progress.track(run!);showWelcome=false
        }
        #endif
    }
    struct Saved:Codable{var progress:TrailCore.Progress;var run:Run?}
    func save(){
        guard persistenceError==nil else{return}
        if let run{progress.track(run)}
        do{try JSONEncoder().encode(Saved(progress:progress,run:run)).write(to:url,options:[.atomic,.completeFileProtectionUntilFirstUserAuthentication])}
        catch{message="Progress couldn’t be saved: \(error.localizedDescription)"}
    }
    func start(_ puzzle:Puzzle,daily:Bool){
        run=Run(puzzle:puzzle,daily:daily);message="";awarded=0;save()
    }
    func submit(_ word:String){
        guard !busy,var next=run else{return}
        do{try next.submit(word);run=next;message="";finishIfNeeded();save()}
        catch{message=error.localizedDescription;UIAccessibility.post(notification:.announcement,argument:message)}
    }
    func finishIfNeeded(){guard let run,run.isComplete else{return};awarded=progress.record(run)}
    func undo(){guard var next=run else{return};next.undo();run=next;message="";save()}
    func hint(){
        guard var next=run,!next.isComplete else{return}
        if let hint=next.nextHint(){next.hints+=1;run=next;message="Try \(hint). Hints turn off the unassisted bonus.";save()}
        else{message="No forward path from here. Undo a step to rejoin the trail."}
    }
    func plant(_ id:String){if progress.plant(id){save()}}
    func welcome(){showWelcome=false;UserDefaults.standard.set(true,forKey:"welcomed")}
}
