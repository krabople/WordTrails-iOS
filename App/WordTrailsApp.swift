import SwiftUI
import TrailCore

@main struct WordTrailsApp: App {
    @StateObject private var store = TrailStore()
    @StateObject private var social = GameCenterService()
    var body: some Scene {
        WindowGroup { RootView().environmentObject(store).environmentObject(social).tint(Palette.ink) }
    }
}

struct RootView: View {
    @EnvironmentObject private var store: TrailStore
    @EnvironmentObject private var social: GameCenterService
    @State private var tab = 0
    var body: some View {
        TabView(selection:$tab) {
            NavigationStack { TrailHome() }.tabItem { Label("Trails",systemImage:"map") }.tag(0)
            NavigationStack { FriendsView() }.tabItem { Label("Together",systemImage:"person.2") }.tag(1)
            NavigationStack { GardenView() }.tabItem { Label("Garden",systemImage:"leaf") }.tag(2)
            NavigationStack { JournalView() }.tabItem { Label("Journal",systemImage:"book.closed") }.tag(3)
        }
        .sheet(isPresented:$store.showWelcome) { WelcomeView() }
        .onChange(of:social.selected?.matchID) { _,value in if value != nil { tab = 1 } }
        .alert("Saved progress needs attention",isPresented:$store.showRecoveryWarning) { Button("Keep playing this session",role:.cancel) {} } message: { Text(store.persistenceError ?? "") }
    }
}
struct WelcomeView: View {
    @EnvironmentObject var store: TrailStore
    var body: some View {
        ScrollView { VStack(alignment:.leading,spacing:24) {
            Landscape().frame(height:190)
            Text("A little wordplay.\nA place to grow.").font(.system(.largeTitle,design:.serif,weight:.medium))
            Text("Change one letter at a time. Every step must make a real word. Reach the destination in as few steps as you can.").font(.title3)
            WordTiles(word:"CAT"); WordTiles(word:"COT",previous:"CAT"); WordTiles(word:"DOT",previous:"COT"); WordTiles(word:"DOG",previous:"DOT")
            Text("Four words. Three steps. That’s a trail.").foregroundStyle(.secondary)
            Text("Play alone, invite a friend, or meet a bot guide. No account is needed for solo or bot play. Your progress stays on this device.")
            Button("Take the first step") { store.welcome() }.buttonStyle(TrailButton())
        }.padding(24) }.interactiveDismissDisabled().presentationDragIndicator(.visible)
    }
}
struct TrailHome: View {
    @EnvironmentObject var store: TrailStore
    @Environment(\.scenePhase) private var scenePhase
    @State private var today = Date()
    @State private var length = 4
    @State private var mode: PlayMode = .solo
    @State private var guide: Guide = .fern
    @State private var playing = false
    @State private var replace: Bool = false
    @State private var pendingDaily = false
    @State private var showSettings = false
    private var daily: Puzzle { TrailCatalog.daily(length:length,date:today) }
    var body: some View {
        ScrollView { VStack(alignment:.leading,spacing:22) {
            HStack { VStack(alignment:.leading,spacing:6) { Text("WORD TRAILS").font(.caption.weight(.semibold)).tracking(3); Text("Find your way.").font(.system(.largeTitle,design:.serif)) }; Spacer(); Label("\(store.progress.streak)",systemImage:"flame").font(.title3).accessibilityLabel("\(store.progress.streak) day streak") }
            Landscape(planted:store.progress.planted.count).frame(height:155).background(Palette.paper,in:RoundedRectangle(cornerRadius:24)).clipShape(RoundedRectangle(cornerRadius:24))
            Picker("Word length",selection:$length) { ForEach(3...6,id:\.self) { Text("\($0) letters").tag($0) } }.pickerStyle(.segmented)
            PaperCard {
                VStack(alignment:.leading,spacing:16) {
                    HStack { Label("Daily trail",systemImage:"sun.max").font(.headline); Spacer(); Text("\(daily.par) steps at par").font(.caption).foregroundStyle(.secondary) }
                    HStack { Text(daily.start); Image(systemName:"arrow.right").font(.title3); Text(daily.goal) }.font(.system(.largeTitle,design:.serif,weight:.medium))
                    Text("A new trail each day. Same words for everyone. Resets at midnight UTC.").font(.subheadline).foregroundStyle(.secondary)
                    Button(store.progress.claimed.contains("\(daily.id)-solo") ? "Play today’s trail again" : "Walk today’s trail") { requestStart(daily:true) }.buttonStyle(TrailButton())
                }
            }
            if let run = store.run, !run.isComplete {
                Button { playing = true } label: { PaperCard { HStack { Image(systemName:"arrow.uturn.forward"); VStack(alignment:.leading) { Text("Continue your trail").font(.headline); Text("\(run.puzzle.start) → \(run.puzzle.goal) · \(run.moves) steps").font(.caption) }; Spacer(); Image(systemName:"chevron.right") } } }.buttonStyle(.plain).accessibilityIdentifier("continueTrail")
            }
            Text("Take another path").font(.system(.title2,design:.serif))
            Picker("Play mode",selection:$mode) { ForEach(PlayMode.allCases) { Text($0.title).tag($0) } }.pickerStyle(.segmented)
            Text(mode == .solo ? "Explore at your own pace. Hints and undo are always available." : mode == .coop ? "Alternate one letter change with your guide. Reach the goal together." : "Solve the same trail as a bot. Fewest steps wins; equal routes draw. No hints or undo.").font(.subheadline).foregroundStyle(.secondary)
            if mode != .solo { Picker("Bot guide",selection:$guide) { ForEach(Guide.allCases) { Text("\($0.name) · Bot").tag($0) } }; Text(guide.caption).font(.caption).foregroundStyle(.secondary) }
            Button(mode == .solo ? "Start a practice trail" : "Play with \(guide.name) · Bot") { requestStart(daily:false) }.buttonStyle(TrailButton())
            Text("3 letters: Meadow · 4: Woodland · 5: Highlands · 6: Summit").font(.caption).foregroundStyle(.secondary)
        }.padding(20) }
        .background(Palette.canvas).navigationTitle("").toolbar { Button { showSettings = true } label:{ Image(systemName:"gearshape") }.accessibilityLabel("Settings and help") }
        .navigationDestination(isPresented:$playing) { LocalPlayView() }
        .sheet(isPresented:$showSettings) { NavigationStack { SettingsView() } }
        .onChange(of:scenePhase) { _,phase in if phase == .active { today = Date() } }
        .task {
            while !Task.isCancelled {
                today = Date()
                let nextDay = (floor(today.timeIntervalSince1970 / 86400) + 1) * 86400
                do { try await Task.sleep(for:.seconds(max(1,nextDay - Date().timeIntervalSince1970))) } catch { return }
            }
        }
        .confirmationDialog("Start a new trail? Your current unfinished trail will be replaced.",isPresented:$replace,titleVisibility:.visible) { Button("Start new trail") { start(daily:pendingDaily) }; Button("Keep current trail",role:.cancel) {} }
    }
    private func requestStart(daily: Bool) { if let run = store.run, !run.isComplete { pendingDaily = daily; replace = true } else { start(daily:daily) } }
    private func start(daily: Bool) {
        let options = TrailCatalog.all.filter { $0.length == length }
        let puzzle = daily ? self.daily : options.randomElement()!
        store.start(puzzle,mode:daily ? .solo : mode,guide:!daily && mode != .solo ? guide : nil,daily:daily); playing = true
    }
}

struct LocalPlayView: View {
    @EnvironmentObject var store: TrailStore
    @State private var input = ""
    @FocusState private var focused: Bool
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView { VStack(alignment:.leading,spacing:18) {
                if let run = store.run {
                    HStack { Label(run.mode.title,systemImage:run.mode == .solo ? "figure.walk" : "person.2"); Spacer(); Text("Par \(run.puzzle.par) · \(run.moves) steps").monospacedDigit() }.font(.subheadline)
                    Text("\(run.puzzle.start) to \(run.puzzle.goal)").font(.system(.largeTitle,design:.serif))
                    if let guide = run.guide { Label("\(guide.name) · Bot · \(guide.caption)",systemImage:guide.symbol).font(.caption).foregroundStyle(.secondary) }
                    if run.mode == .versus { Text("Fewest steps wins. Your opponent’s route is revealed at the end.").font(.subheadline).foregroundStyle(.secondary) }
                    ForEach(Array(run.chain.enumerated()),id:\.offset) { i,word in
                        VStack(spacing:8) { if i > 0 { Image(systemName:"arrow.down").font(.caption).foregroundStyle(.secondary) }; WordTiles(word:word,previous:i > 0 ? run.chain[i-1] : nil,active:i == run.chain.count-1); if run.mode == .coop && i > 0 { Text(i.isMultiple(of:2) ? "\(run.guide?.name ?? "Guide") · Bot" : "You").font(.caption2).foregroundStyle(.secondary) } }
                    }
                    if run.isComplete { completion(run) }
                    else {
                        VStack(alignment:.leading,spacing:12) {
                            Text(store.busy ? "\(run.guide?.name ?? "Guide") is finding a step…" : "Change one letter to make the next word.").font(.subheadline)
                            HStack { TextField("\(run.puzzle.length)-letter word",text:$input).textInputAutocapitalization(.characters).autocorrectionDisabled().keyboardType(.asciiCapable).font(.system(.title2,design:.monospaced)).submitLabel(.go).focused($focused).onSubmit(submit).accessibilityIdentifier("wordInput"); Button("Add step",action:submit).font(.headline).disabled(store.busy || input.isEmpty).accessibilityIdentifier("submitWord") }.padding(14).background(Color(.secondarySystemGroupedBackground),in:RoundedRectangle(cornerRadius:14))
                            if run.mode != .versus { HStack { Button("Undo",systemImage:"arrow.uturn.backward") { store.undo() }.disabled(run.moves == 0 || store.busy); Spacer(); Button("Hint",systemImage:"lightbulb") { store.hint() }.disabled(store.busy) }.buttonStyle(.bordered) }
                            Text("Goal: \(run.puzzle.goal)").font(.headline).foregroundStyle(Palette.ink)
                        }.id("input")
                    }
                    if !store.message.isEmpty { Text(store.message).font(.subheadline).foregroundStyle(.secondary).accessibilityIdentifier("gameMessage") }
                }
            }.padding(20) }.background(Palette.canvas)
            .onChange(of:store.run?.chain.count) { _,_ in withAnimation { proxy.scrollTo("input",anchor:.bottom) } }
        }.navigationTitle("On the trail").navigationBarTitleDisplayMode(.inline)
        .onDisappear { store.save() }
        .task { if let run = store.run, run.mode == .coop, run.guide != nil, !run.isComplete, !run.moves.isMultiple(of:2), !store.busy { store.takeBotTurn() } }
    }
    private func submit() { store.submit(input); if store.message.isEmpty { input = "" }; if store.run?.isComplete == true { focused = false } }
    @ViewBuilder private func completion(_ run: Run) -> some View {
        PaperCard { VStack(alignment:.leading,spacing:14) {
            Label(run.result,systemImage:"checkmark.seal.fill").font(.title2)
            Text("\(run.moves) steps · Par \(run.puzzle.par)").font(.headline)
            Text(store.awarded > 0 ? "+\(store.awarded) seeds for your garden" : "A lovely walk. Seeds are awarded once per trail and mode.").foregroundStyle(.secondary)
            if run.mode == .versus, let guide = run.guide {
                Text("\(guide.name)’s route · \(run.botMoves!) steps").font(.headline)
                Text(guide.route(for:run.puzzle).joined(separator:" → ")).font(.system(.subheadline,design:.monospaced))
            }
            ShareLink(item:"Word Trails\(run.isDaily ? " daily" : "") · \(run.puzzle.length) letters\n\(run.moves) steps · Par \(run.puzzle.par)\n\(run.hints == 0 ? "No hints" : "\(run.hints) hints")\nCan you find your way?") { Label("Share your result",systemImage:"square.and.arrow.up") }
        } }
    }
}
