import SwiftUI
import TrailCore

struct GardenView: View {
    @EnvironmentObject private var store: TrailStore
    @EnvironmentObject private var social: GameCenterService
    @State private var confirm: String?
    var body: some View {
        ScrollView { VStack(alignment:.leading,spacing:22) {
            Text("Small steps.\nSomething growing.").font(.system(.largeTitle,design:.serif))
            Landscape(planted:store.progress.planted.count).frame(height:210).background(Palette.paper,in:RoundedRectangle(cornerRadius:24)).clipShape(RoundedRectangle(cornerRadius:24))
            HStack { Label("\(store.progress.seeds) seeds",systemImage:"leaf.fill").font(.title3.weight(.semibold)); Spacer(); Text("\(store.progress.planted.count) / \(Plant.all.count) planted").foregroundStyle(.secondary) }
            Text("Earn 3 seeds the first time you complete each trail in each mode. A route at par with no hints earns 2 more. Plant something for 10 seeds. Replays are always welcome.").font(.subheadline).foregroundStyle(.secondary)
            LazyVGrid(columns:[GridItem(.adaptive(minimum:145))],spacing:14) {
                ForEach(Plant.all) { plant in
                    let planted = store.progress.planted.contains(plant.id)
                    VStack(spacing:14) {
                        Image(systemName:plant.symbol).font(.system(size:38,weight:.light)).foregroundStyle(planted ? Palette.ink : .secondary).frame(height:56)
                        Text(plant.name).font(.headline)
                        Button(planted ? "Growing" : "Plant · 10 seeds") { confirm = plant.id }.buttonStyle(.bordered).disabled(planted || store.progress.seeds < 10)
                    }.frame(maxWidth:.infinity).padding(18).background(Color(.secondarySystemGroupedBackground),in:RoundedRectangle(cornerRadius:20))
                }
            }
            Text("Your garden is personal to this device. There are no purchases, ads, or expiring rewards.").font(.caption).foregroundStyle(.secondary)
            Text("Gardens together").font(.system(.title2,design:.serif))
            Text("Every completed co-op trail grows a garden with that partner. New plants appear after 1, 3, 5, 8, 12 and 20 walks together. Human partners see the same milestones from their shared match history.").font(.subheadline).foregroundStyle(.secondary)
            if store.progress.sharedGardens.isEmpty { Text("Finish a co-op trail with a friend or a bot guide to plant your first shared garden.").foregroundStyle(.secondary) }
            ForEach(store.progress.sharedGardens) { garden in
                PaperCard { VStack(alignment:.leading,spacing:12) {
                    Text("You + \(garden.name)").font(.headline)
                    Landscape(planted:garden.plants).frame(height:100)
                    Text("\(garden.completedTrails.count) walks together · \(garden.plants) plants").font(.subheadline)
                    if let next = garden.nextMilestone { Text("Next plant at \(next) co-op trails").font(.caption).foregroundStyle(.secondary) }
                } }
            }
        }.padding(20) }.background(Palette.canvas).navigationTitle("Garden")
        .task { social.syncGardens(into:store) }
        .confirmationDialog("Plant for 10 seeds?",isPresented:Binding(get:{confirm != nil},set:{if !$0 {confirm = nil}}),titleVisibility:.visible) { Button("Plant") { if let confirm { store.plant(confirm) }; confirm = nil }; Button("Cancel",role:.cancel) { confirm = nil } }
    }
}
struct JournalView: View {
    @EnvironmentObject private var store: TrailStore
    var body: some View {
        List {
            Section {
                HStack { stat("Trails",value:store.progress.completed.count); Spacer(); stat("Day streak",value:store.progress.streak); Spacer(); stat("Badges",value:store.progress.badges.count) }
            }
            Section("Your badges") {
                ForEach(Badge.all) { badge in
                    let unlocked = store.progress.badges.contains(badge.id)
                    HStack(spacing:16) {
                        Image(systemName:badge.symbol).font(.title2).foregroundStyle(unlocked ? Palette.ochre : .secondary).frame(width:36)
                        VStack(alignment:.leading,spacing:4) { Text(badge.title).font(.headline); Text(badge.detail).font(.caption).foregroundStyle(.secondary) }
                        Spacer(); Image(systemName:unlocked ? "checkmark.seal.fill" : "lock").foregroundStyle(unlocked ? Palette.ink : .secondary)
                    }.accessibilityElement(children:.combine).accessibilityLabel("\(badge.title). \(badge.detail). \(unlocked ? "Earned" : "Locked")")
                }
            }
            Section("Recent walks") {
                if store.progress.completed.isEmpty { Text("Your first trail is waiting. Completed trails and routes will appear here.").foregroundStyle(.secondary) }
                ForEach(Array(store.progress.completed.suffix(40).reversed())) { run in
                    DisclosureGroup {
                        Text(run.chain.joined(separator:" → ")).font(.system(.subheadline,design:.monospaced))
                        Text("\(run.hints) hints · \(run.totalMoves) submitted steps").font(.caption)
                    } label: {
                        VStack(alignment:.leading,spacing:5) { Text("\(run.puzzle.start) → \(run.puzzle.goal)").font(.headline); Text("\(run.mode.title) · \(run.moves) steps · Par \(run.puzzle.par)").font(.caption).foregroundStyle(.secondary) }
                    }
                }
            }
        }.navigationTitle("Journal")
    }
    private func stat(_ label:String,value:Int) -> some View { VStack(alignment:.leading) { Text("\(value)").font(.system(.largeTitle,design:.serif)); Text(label).font(.caption).foregroundStyle(.secondary) } }
}
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: TrailStore
    @State private var licenses = ""
    var body: some View {
        List {
            Section("How to walk a trail") {
                Text("Change exactly one letter at a time. Keep the word length, use an English word in the game dictionary, and don’t repeat a word. No names, spaces, hyphens, or rearranging letters. Plurals and inflections are allowed when included.")
                Text("Par is the shortest possible route in the bundled dictionary. A trail’s steps count letter changes, so CAT → COT → DOT → DOG is three steps.")
                Text("Solo: hints and undo are available. Bot co-op: take turns with a guide; undo returns to your previous turn. Versus and online play: no hints or undo. Versus compares final route length, with ties drawn.")
                Text("Moves that would leave no route to the destination are rejected, so you cannot become trapped. Online players can forfeit in Game Center’s match picker. There are no ranked prizes or cash rewards.")
            }
            Section("Dictionary") {
                Text("\(Lexicon.shared.words.count.formatted()) curated English words, 3–6 letters. The same version is used by everyone, including the bots. The dictionary is deliberately bounded: not every English word is accepted. Both players need a compatible app version.")
                NavigationLink("Browse accepted words") { DictionaryView() }
            }
            Section("Daily trails and rewards") {
                Text("A new puzzle for each word length appears at 00:00 UTC. Finish a current daily trail to build your streak. Finishing yesterday’s saved trail still earns seeds but does not backdate your streak. Seeds are awarded only once for each trail and mode.")
                Text("The garden has six collectible plants. Badge progress includes trails with bot guides. Your garden, journal, badges and saved solo trail stay on this device; reinstalling the app removes them unless restored with an iPhone backup.")
                Text("Shared gardens grow through completed co-op trails with each partner. Human shared milestones can be recovered from completed Game Center matches. Keep completed matches in Game Center if you want to recover that history on another device.")
            }
            Section("Friends and privacy") {
                Text("Solo and bots need no account or internet connection. Human play uses Apple Game Center for identity, friends, matchmaking, match storage and turn alerts. You explicitly choose when to sign in or request friend access. Word Trails has no advertising, analytics SDK, chat, contact upload or independent account database.")
                Text("Bot guides are clearly labelled. They have no Apple accounts, never impersonate users, and don’t appear in human matchmaking. Game Center friends and blocking are managed in Apple’s Game Center settings.")
                Text("Game Center activity is subject to Apple’s privacy policy.")
                Link("Apple Game Center and privacy",destination:URL(string:"https://www.apple.com/legal/privacy/data/en/game-center/")!)
            }
            Section("Accessibility") { Text("Word Trails follows your system text size and appearance. Letter changes use both position and shading. VoiceOver reads words letter by letter. All scenes are static, with no motion needed to play. Larger text may require scrolling.") }
            Section { Text("Word Trails · Version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0") (\(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"))").font(.caption); Text("Artwork is drawn from original vector geometry and Apple SF Symbols. No generated raster artwork or stock player portraits.").font(.caption).foregroundStyle(.secondary) }
        }.navigationTitle("Field notes").toolbar { Button("Done") { dismiss() } }
    }
}
struct DictionaryView: View {
    @State private var query = ""
    private var results: [String] { Lexicon.shared.words.filter { query.isEmpty || $0.contains(query.uppercased()) }.sorted() }
    var body: some View { List { Section("\(results.count) words") { ForEach(results,id:\.self) { Text($0).font(.system(.body,design:.monospaced)) } } }.searchable(text:$query,prompt:"Find a word").navigationTitle("Trail dictionary") }
}
