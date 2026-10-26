import SwiftUI
import TrailCore

@main struct WordTrailsApp:App {
    @StateObject private var store=TrailStore()
    @StateObject private var social=GameCenterService()
    @StateObject private var reminders=ReminderService()
    private var testingColorScheme:ColorScheme? {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--ui-test") && ProcessInfo.processInfo.arguments.contains("--dark-mode"){return .dark}
        #endif
        return nil
    }
    var body:some Scene {
        WindowGroup{RootView().environmentObject(store).environmentObject(social).environmentObject(reminders).tint(Palette.ink).preferredColorScheme(testingColorScheme)}
    }
}
struct RootView:View {
    @EnvironmentObject private var store:TrailStore
    @EnvironmentObject private var social:GameCenterService
    @EnvironmentObject private var reminders:ReminderService
    @Environment(\.scenePhase) private var scenePhase
    @State private var tab=0
    var body:some View {
        TabView(selection:$tab){
            NavigationStack{TrailHome()}.tabItem{Label("Trails",systemImage:"map")}.tag(0)
            NavigationStack{FriendsView()}.tabItem{Label("Co-op",systemImage:"person.2")}.tag(1)
            NavigationStack{GardenView()}.tabItem{Label("Garden",systemImage:"leaf")}.tag(2)
            NavigationStack{JournalView()}.tabItem{Label("Stats",systemImage:"chart.bar")}.tag(3)
        }
        .sheet(isPresented:$store.showWelcome){WelcomeView()}
        .onChange(of:social.selected?.matchID){_,value in if value != nil{tab=1}}
        .onChange(of:scenePhase){_,phase in if phase == .active{Task{await reminders.refresh()}}}
        .task{if !ProcessInfo.processInfo.arguments.contains("--ui-test"){await reminders.refresh()}}
        .alert(store.showRecoveryWarning ? "Saved progress needs attention":store.newBadges.count==1 ? "New badge earned":"New badges earned",isPresented:Binding(get:{store.showRecoveryWarning || (!store.showWelcome && !store.newBadges.isEmpty)},set:{if !$0{if store.showRecoveryWarning{store.showRecoveryWarning=false}else{store.acknowledgeBadges()}}})){
            if store.showRecoveryWarning{Button("Keep playing this session",role:.cancel){store.showRecoveryWarning=false}}
            else{Button("Lovely"){store.acknowledgeBadges()}}
        }message:{Text(store.showRecoveryWarning ? (store.persistenceError ?? ""):store.newBadges.map{"\($0.title)\n\($0.detail)"}.joined(separator:"\n\n"))}

    }
}
struct WelcomeView:View {
    @EnvironmentObject var store:TrailStore
    var body:some View {
        ScrollView{VStack(alignment:.leading,spacing:24){
            Landscape().frame(height:180)
            Text("A little wordplay.\nA place to grow.").font(.system(.largeTitle,design:.serif,weight:.medium))
            Text("Your daily word trail. Change one letter at a time, make a word at every step, and find your way to the destination.").font(.title3)
            WordTiles(word:"CAT");WordTiles(word:"COT",previous:"CAT");WordTiles(word:"DOT",previous:"COT");WordTiles(word:"DOG",previous:"DOT")
            Text("Four words. Three steps.").foregroundStyle(.secondary)
            Text("Play on your own, at your own pace. Or invite a friend for an optional co-op trail. No account is needed for solo play.")
            Text("Beat par by finding a short route. A shortest solution is always possible using familiar words, and you can use unusual dictionary words too.").font(.subheadline)
            Button("Take the first step"){store.welcome()}.buttonStyle(TrailButton())
        }.padding(24)}.interactiveDismissDisabled().presentationDragIndicator(.visible)
    }
}
struct TrailHome:View {
    @EnvironmentObject var store:TrailStore
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var textSize
    @State private var today=Date()
    @State private var length=4
    @State private var playing=false
    @State private var replace=false
    @State private var pendingDaily=false
    @State private var showSettings=false
    @State private var showReminders=false
    private var daily:Puzzle{TrailCatalog.daily(length:length,date:today)}
    private var dailyAttempt:Run?{store.progress.completedAttempts(puzzleID:daily.id,mode:.solo).first}
    var body:some View {
        ScrollView{VStack(alignment:.leading,spacing:22){
            if textSize.isAccessibilitySize{VStack(alignment:.leading,spacing:12){homeHeading;streak}}
            else{HStack{homeHeading;Spacer();streak}}
            Landscape(planted:store.progress.planted.count).frame(height:155).background(Palette.paper,in:RoundedRectangle(cornerRadius:24)).clipShape(RoundedRectangle(cornerRadius:24))
            Picker("Word length",selection:$length){ForEach(3...6,id:\.self){Text("\($0) letters").tag($0)}}.pickerStyle(.segmented)
            dailyCard
            if let run=store.run,!run.isComplete {
                Button{playing=true}label:{PaperCard{HStack{Image(systemName:"arrow.uturn.forward");VStack(alignment:.leading){Text("Continue your trail").font(.headline);Text("\(run.puzzle.start) → \(run.puzzle.goal) · \(run.moves) steps").font(.caption)};Spacer();Image(systemName:"chevron.right")}}}.buttonStyle(.plain).accessibilityIdentifier("continueTrail")
            }
            if !store.progress.completed.isEmpty {
                NavigationLink{CompletedTrailsView()}label:{Label("Completed trails",systemImage:"clock.arrow.circlepath")}.buttonStyle(.bordered).accessibilityIdentifier("completedTrailHistory")
            }
            Text("A quiet daily challenge").font(.system(.title2,design:.serif))
            Text("No timer. No opponent. Find your route, beat par, and grow a little each day.").font(.subheadline).foregroundStyle(.secondary)
            Button("Start a practice trail"){requestStart(daily:false)}.buttonStyle(.bordered).frame(maxWidth:.infinity).accessibilityIdentifier("practiceTrail")
        }.padding(20)}
        .background(Palette.canvas).navigationTitle("")
        .toolbar{
            Button{showReminders=true}label:{Image(systemName:"bell")}.accessibilityLabel("Daily reminder").accessibilityIdentifier("reminderSettings")
            Button{showSettings=true}label:{Image(systemName:"gearshape")}.accessibilityLabel("Settings and help")
        }
        .navigationDestination(isPresented:$playing){LocalPlayView()}
        .sheet(isPresented:$showSettings){NavigationStack{SettingsView()}}
        .sheet(isPresented:$showReminders){NavigationStack{ReminderSettingsView().toolbar{Button("Done"){showReminders=false}}}}
        .onChange(of:scenePhase){_,phase in if phase == .active{today=Date()}}
        .task{while !Task.isCancelled{today=Date();let nextDay=(floor(today.timeIntervalSince1970/86400)+1)*86400;do{try await Task.sleep(for:.seconds(max(1,nextDay-Date().timeIntervalSince1970)))}catch{return}}}
        .confirmationDialog("Start a new trail? Your current unfinished trail will be replaced.",isPresented:$replace,titleVisibility:.visible){Button("Start new trail"){start(daily:pendingDaily)};Button("Keep current trail",role:.cancel){}}
    }
    private var dailyCard:some View {
        PaperCard{VStack(alignment:.leading,spacing:16){
            if textSize.isAccessibilitySize{VStack(alignment:.leading,spacing:8){Label("Daily trail",systemImage:"sun.max").font(.headline);Text("Par \(daily.par)").font(.caption).foregroundStyle(.secondary)}}
            else{HStack{Label("Daily trail",systemImage:"sun.max").font(.headline);Spacer();Text("Par \(daily.par)").font(.caption).foregroundStyle(.secondary)}}
            HStack{Text(daily.start);Image(systemName:"arrow.right").font(.title3);Text(daily.goal)}.font(.system(.largeTitle,design:.serif,weight:.medium)).lineLimit(1).minimumScaleFactor(0.4)
            Text("A fresh trail each day. Same puzzle for everyone. Resets at midnight UTC.").font(.subheadline).foregroundStyle(.secondary)
            Text("Shortest route: \(daily.minimum) steps · Can you beat par?").font(.caption).foregroundStyle(.secondary)
            if let attempt=dailyAttempt {
                NavigationLink{CompletedAttemptView(run:attempt)}label:{Label("View completed trail",systemImage:"checkmark.circle")}.buttonStyle(TrailButton()).accessibilityIdentifier("viewCompletedDaily")
                Button("Play today’s trail again"){requestStart(daily:true)}.buttonStyle(.bordered).accessibilityIdentifier("replayDaily")
            }else{
                Button("Walk today’s trail"){requestStart(daily:true)}.buttonStyle(TrailButton())
            }
        }}
    }
    private var homeHeading:some View{VStack(alignment:.leading,spacing:6){Text("WORD TRAILS").font(.caption.weight(.semibold)).tracking(3).dynamicTypeSize(...DynamicTypeSize.xxxLarge);Text("Find your way.").font(.system(.largeTitle,design:.serif))}}
    private var streak:some View{Label("\(store.progress.streak)",systemImage:"flame").font(.title3).accessibilityLabel("\(store.progress.streak) day streak")}
    private func requestStart(daily:Bool){if let run=store.run,!run.isComplete{pendingDaily=daily;replace=true}else{start(daily:daily)}}
    private func start(daily:Bool){let puzzle=daily ? self.daily:TrailCatalog.puzzles(length:length).randomElement()!;store.start(puzzle,daily:daily);playing=true}
}
struct LocalPlayView:View {
    @EnvironmentObject var store:TrailStore
    @State private var input=""
    @State private var sharing=false
    @FocusState private var focused:Bool
    var body:some View {
        ScrollViewReader{proxy in
            ScrollView{VStack(alignment:.leading,spacing:18){
                if let run=store.run{
                    HStack{Label(run.isDaily ? "Daily":"Practice",systemImage:"figure.walk");Spacer();Text("Par \(run.puzzle.par) · \(run.moves) steps").monospacedDigit()}.font(.subheadline)
                    Text("\(run.puzzle.start) to \(run.puzzle.goal)").font(.system(.largeTitle,design:.serif))
                    Text("Shortest possible: \(run.puzzle.minimum) steps").font(.caption).foregroundStyle(.secondary)
                    ForEach(Array(run.chain.enumerated()),id:\.offset){i,word in VStack(spacing:8){if i>0{Image(systemName:"arrow.down").font(.caption).foregroundStyle(.secondary)};WordTiles(word:word,previous:i>0 ? run.chain[i-1]:nil,active:i==run.chain.count-1)}}
                    if run.isComplete{completion(run).id("completion")}
                    else{VStack(alignment:.leading,spacing:12){
                        Text("Change one letter to make the next word.").font(.subheadline)
                        HStack{TextField("\(run.puzzle.length)-letter word",text:$input).textInputAutocapitalization(.characters).autocorrectionDisabled().keyboardType(.asciiCapable).font(.system(.title2,design:.monospaced)).submitLabel(.go).focused($focused).onSubmit(submit).accessibilityIdentifier("wordInput");Button("Add step",action:submit).font(.headline).frame(minHeight:44).disabled(input.isEmpty).accessibilityIdentifier("submitWord")}.padding(14).background(Color(.secondarySystemGroupedBackground),in:RoundedRectangle(cornerRadius:14))
                        HStack{Button("Undo",systemImage:"arrow.uturn.backward"){store.undo()}.disabled(run.moves==0);Spacer();Button("Hint",systemImage:"lightbulb"){store.hint()}}.buttonStyle(.bordered)
                        Text("Goal: \(run.puzzle.goal)").font(.headline).foregroundStyle(Palette.ink)
                    }.id("input")}
                    if !store.message.isEmpty{Text(store.message).font(.subheadline).foregroundStyle(.secondary).accessibilityIdentifier("gameMessage")}
                }
            }.padding(20)}.background(Palette.canvas)
            .onChange(of:store.run?.chain.count){_,_ in withAnimation{proxy.scrollTo(store.run?.isComplete == true ? "completion":"input",anchor:.bottom)}}
        }.navigationTitle("On the trail").navigationBarTitleDisplayMode(.inline).onDisappear{store.save()}
        .sheet(isPresented:$sharing){if let run=store.run{ResultShareView(run:run)}}
    }
    private func submit(){store.submit(input);if store.message.isEmpty{input=""};if store.run?.isComplete==true{focused=false}}
    private func completion(_ run:Run)->some View{
        PaperCard{VStack(alignment:.leading,spacing:14){
            Label("Trail complete",systemImage:"checkmark.seal.fill").font(.title2)
            if run.isShortestSolution{ShortestRouteAcknowledgement()}
            Text(run.scoreDescription).font(.title2.weight(.semibold)).foregroundStyle(Palette.ink).accessibilityIdentifier("parResult")
            Text("\(run.moves) steps · Par \(run.puzzle.par) · Minimum \(run.puzzle.minimum)").font(.headline)
            Text(store.awarded>0 ? "+\(store.awarded) seeds for your garden":"A lovely walk. Seeds are awarded once per trail and mode.").foregroundStyle(.secondary)
            Button("Share your result",systemImage:"square.and.arrow.up"){sharing=true}.accessibilityIdentifier("shareResult")
        }}
    }
}
