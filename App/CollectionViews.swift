import SwiftUI
import TrailCore

struct GardenView: View {
    @EnvironmentObject private var store: TrailStore
    @EnvironmentObject private var social: GameCenterService
    @Environment(\.dynamicTypeSize) private var textSize
    @State private var confirm: String?
    var body: some View {
        ScrollView { VStack(alignment:.leading,spacing:22) {
            Text("Small steps.\nSomething growing.").font(.system(.largeTitle,design:.serif))
            Landscape(planted:store.progress.planted.count).frame(height:210).background(Palette.paper,in:RoundedRectangle(cornerRadius:24)).clipShape(RoundedRectangle(cornerRadius:24))
            if textSize.isAccessibilitySize {
                VStack(alignment:.leading,spacing:10) { Label("\(store.progress.seeds) seeds",systemImage:"leaf.fill").font(.title3.weight(.semibold)); Text("\(store.progress.planted.count) / \(Plant.all.count) planted").foregroundStyle(.secondary) }
            } else { HStack { Label("\(store.progress.seeds) seeds",systemImage:"leaf.fill").font(.title3.weight(.semibold)); Spacer(); Text("\(store.progress.planted.count) / \(Plant.all.count) planted").foregroundStyle(.secondary) } }
            Text("Earn 3 seeds the first time you complete each trail in each mode. A route at or under par with no hints earns 2 more. Plant something for 10 seeds. Replays are always welcome.").font(.subheadline).foregroundStyle(.secondary)
            LazyVGrid(columns:textSize.isAccessibilitySize ? [GridItem(.flexible())] : [GridItem(.adaptive(minimum:145))],spacing:14) {
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
            Text("Every completed co-op trail grows a garden with that partner. New plants appear after 1, 3, 5, 8, 12 and 20 walks together. Partners see the same milestones from their shared match history.").font(.subheadline).foregroundStyle(.secondary)
            if store.progress.sharedGardens.isEmpty { Text("Finish a co-op trail with a friend to plant your first shared garden.").foregroundStyle(.secondary) }
            ForEach(store.progress.sharedGardens) { garden in
                PaperCard { VStack(alignment:.leading,spacing:12) {
                    Text("You + \(garden.name)").font(.headline)
                    Landscape(planted:garden.plants).frame(height:100)
                    Text("\(garden.completedTrails.count) \(garden.completedTrails.count == 1 ? "walk" : "walks") together · \(garden.plants) \(garden.plants == 1 ? "plant" : "plants")").font(.subheadline)
                    if let next = garden.nextMilestone { Text("Next plant at \(next) co-op trails").font(.caption).foregroundStyle(.secondary) }
                } }
            }
        }.padding(20) }.background(Palette.canvas).navigationTitle("Garden")
        .task { social.syncGardens(into:store) }
        .confirmationDialog("Plant for 10 seeds?",isPresented:Binding(get:{confirm != nil},set:{if !$0 {confirm = nil}}),titleVisibility:.visible) { Button("Plant") { if let confirm { store.plant(confirm) }; confirm = nil }; Button("Cancel",role:.cancel) { confirm = nil } }
    }
}
struct JournalView:View {
    @EnvironmentObject private var store:TrailStore
    private let names=[3:"Meadow",4:"Woodland",5:"Highlands",6:"Summit"]
    var body:some View {
        List{
            Section("At a glance"){
                LabeledContent("Trails attempted",value:"\(store.progress.attempts.count)").accessibilityElement(children:.ignore).accessibilityLabel("Trails attempted").accessibilityValue("\(store.progress.attempts.count)").accessibilityIdentifier("totalAttempts")
                LabeledContent("Trails completed",value:"\(store.progress.completed.count)").accessibilityElement(children:.ignore).accessibilityLabel("Trails completed").accessibilityValue("\(store.progress.completed.count)").accessibilityIdentifier("totalCompleted")
                LabeledContent("Daily streak",value:"\(store.progress.streak) days")
                LabeledContent("Badges",value:"\(Badge.all.filter{store.progress.badges.contains($0.id)}.count)")
            }
            Section{NavigationLink{CompletedTrailsView()}label:{Label("View completed trails",systemImage:"clock.arrow.circlepath")}.accessibilityIdentifier("completedTrailHistory")}
            Section("By difficulty"){
                ForEach(3...6,id:\.self){length in
                    DisclosureGroup{
                        DifficultyStatsView(stats:store.progress.statistics(length:length))
                    }label:{VStack(alignment:.leading,spacing:4){
                        Text("\(names[length]!) · \(length) letters")
                        Text("\(store.progress.statistics(length:length).completed) completed / \(store.progress.statistics(length:length).attempted) attempted").font(.caption).foregroundStyle(.secondary)
                    }}.accessibilityIdentifier("difficultyStats\(length)")
                }
            }
            Section("Overall results against par"){DifficultyStatsView(stats:store.progress.statistics())}
            Section{Text("Attempt counts include your earlier completed trails. Abandoned attempts are tracked from this update onward. Older results keep the par they were played with.").font(.caption).foregroundStyle(.secondary)}
            Section("Your badges"){
                ForEach(Badge.all){badge in
                    let unlocked=store.progress.badges.contains(badge.id)
                    HStack(spacing:16){
                        Image(systemName:badge.symbol).font(.title2).foregroundStyle(unlocked ? Palette.ochre:.secondary).frame(width:36)
                        VStack(alignment:.leading,spacing:4){Text(badge.title).font(.headline);Text(badge.detail).font(.caption).foregroundStyle(.secondary)}
                        Spacer();Image(systemName:unlocked ? "checkmark.seal.fill":"lock").foregroundStyle(unlocked ? Palette.ink:.secondary)
                    }.accessibilityElement(children:.combine).accessibilityLabel("\(badge.title). \(badge.detail). \(unlocked ? "Earned":"Locked")")
                }
            }
            Section("Recent walks"){
                if store.progress.completed.isEmpty{Text("Your first trail is waiting. Completed routes will appear here.").foregroundStyle(.secondary)}
                ForEach(Array(store.progress.completedAttempts().prefix(40))){run in
                    NavigationLink{CompletedAttemptView(run:run)}label:{CompletedTrailRow(run:run)}
                }
            }
        }.navigationTitle("Statistics")
    }
}
struct DifficultyStatsView:View {
    let stats:DifficultyStatistics
    var body:some View {
        LabeledContent("Attempted",value:"\(stats.attempted)")
        LabeledContent("Completed",value:"\(stats.completed)")
        LabeledContent("Completion rate",value:stats.completionRate.formatted(.percent.precision(.fractionLength(0))))
        LabeledContent("Below par",value:"\(stats.underPar)")
        LabeledContent("On par",value:"\(stats.onPar)")
        LabeledContent("Above par",value:"\(stats.overPar)")
        LabeledContent("Shortest routes",value:"\(stats.shortestRoutes)")
        if let average=stats.averageMoves{LabeledContent("Average steps",value:average.formatted(.number.precision(.fractionLength(1))))}
        if let average=stats.averageAgainstPar{LabeledContent("Average vs par",value:average.formatted(.number.sign(strategy:.always()).precision(.fractionLength(1))))}
        if let best=stats.bestAgainstPar{LabeledContent("Best vs par",value:best.formatted(.number.sign(strategy:.always())))}
    }
}
struct SettingsView:View {
    @Environment(\.dismiss) private var dismiss
    var body:some View {
        List{
            Section("Daily reminder"){NavigationLink{ReminderSettingsView()}label:{Label("Choose reminder time",systemImage:"bell")}}
            Section("How to walk a trail"){
                Text("Change exactly one letter at a time. Keep the word length, use a word from the dictionary, and don’t repeat a word. Spaces, hyphens and rearranging letters are not allowed. Plurals and inflected forms are included.")
                Text("A step is one letter change. CAT → COT → DOT → DOG takes three steps.")
                Text("Par is your target, not the minimum. Three- and four-letter trails allow one step above the shortest route; five- and six-letter trails allow two. Finishing in fewer steps puts you under par. Par is a difficulty-based target, not a measured player average.")
                Text("Every new trail has a shortest solution using familiar words. More unusual dictionary words are also accepted, but aren’t required to reach the minimum. Hints prefer familiar words whenever they can still complete a shortest route from your current position. Your earlier choices may leave a shortest continuation that needs unusual words; undo can open up other routes.")
                Text("Solo trails have hints and undo. Optional co-op trails alternate turns with a friend through Game Center. Both players share the route and score; online trails do not have hints or undo.")
                Text("A move that would make the goal unreachable without repeating a word is rejected.")
            }
            Section("English dictionary"){
                Text("\(Lexicon.shared.words.count.formatted()) accepted words for the current 3–6-letter games. Based on the comprehensive ESDB English word lists, including British, American, Canadian and Australian spellings, inflections and uncommon vocabulary. Only A–Z word forms fit these trails; proper names, abbreviations, spaces and hyphens are excluded.")
                NavigationLink("Browse accepted words"){DictionaryView()}
                NavigationLink("Dictionary source and licence"){ScrollView{Text(Lexicon.licence).font(.caption).padding()}.navigationTitle("Dictionary licence")}
            }
            Section("Daily trails and rewards"){
                Text("Discover a fresh trail every day. Everyone gets the same daily puzzle at each difficulty, with a new trail appearing at midnight UTC.")
                Text("Finish a current daily trail to build your streak. Old saved trails can still earn seeds but cannot backdate your streak. The first completion of each trail in each mode earns 3 seeds, plus 2 for finishing at or below par without hints. Replays do not award more seeds.")
                Text("Your earlier seeds, plants, streak and completed trails are preserved. Personal progress stays on this device. Shared gardens can be recovered from completed co-op matches retained in Game Center.")
            }
            Section("Privacy"){
                Text("Solo play and daily reminders work without an account or internet connection. Your iPhone schedules reminders only after you opt in. Co-op uses Apple Game Center for identity, friends, match storage and turn alerts. No advertising, analytics SDK, chat, contact upload or independent account database.")
                Link("Apple Game Center and privacy",destination:URL(string:"https://www.apple.com/legal/privacy/data/en/game-center/")!)
            }
            Section("Accessibility"){Text("System text sizes, dark mode and VoiceOver are supported. Changed letters are underlined as well as tinted. Scenes are static; larger text can be read by scrolling.")}
            Section{Text("Word Trails · Version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.1") (\(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"))").font(.caption)}
        }.navigationTitle("Field notes").toolbar{Button("Done"){dismiss()}}
    }
}
struct DictionaryView:View {
    @State private var query=""
    private var results:[String]{query.isEmpty ? Lexicon.shared.sortedWords:Lexicon.shared.sortedWords.filter{$0.contains(query.uppercased())}}
    var body:some View{List{Section("\(results.count) words"){ForEach(results,id:\.self){Text($0).font(.system(.body,design:.monospaced))}}}.searchable(text:$query,prompt:"Find a word").navigationTitle("Trail dictionary")}
}
