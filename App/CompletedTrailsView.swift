import SwiftUI
import TrailCore

struct ShortestRouteAcknowledgement:View {
    var body:some View {
        Label("Shortest possible route",systemImage:"rosette").font(.headline).foregroundStyle(Palette.ink).padding(12).frame(maxWidth:.infinity,alignment:.leading).background(Palette.sage.opacity(0.25),in:RoundedRectangle(cornerRadius:12)).accessibilityIdentifier("shortestRouteAcknowledgement")
    }
}

struct CompletedTrailsView:View {
    @EnvironmentObject private var store:TrailStore
    @State private var query=""
    private var attempts:[Run]{
        let search=query.trimmingCharacters(in:.whitespacesAndNewlines).uppercased()
        return store.progress.completedAttempts().filter{search.isEmpty || $0.chain.contains(where:{$0.contains(search)})}
    }
    var body:some View {
        List{
            if attempts.isEmpty{Text(query.isEmpty ? "Your completed trails will appear here.":"No completed trails match your search.").foregroundStyle(.secondary)}
            ForEach(attempts){run in
                NavigationLink{CompletedAttemptView(run:run)}label:{CompletedTrailRow(run:run)}.accessibilityIdentifier("completedAttempt-\(run.id.uuidString)")
            }
        }.trailListWidth().navigationTitle("Completed trails").searchable(text:$query,prompt:"Find a word in your route")
    }
}
struct CompletedTrailRow:View {
    let run:Run
    var body:some View {
        VStack(alignment:.leading,spacing:5){
            Text("\(run.puzzle.start) → \(run.puzzle.goal)").font(.headline)
            Text("\(run.isDaily ? "Daily":run.mode.title) · \(run.moves) steps · \(run.scoreDescription)").font(.caption).foregroundStyle(.secondary)
            if let date=run.finishedAt{Text(date,format:.dateTime.day().month().year().hour().minute()).font(.caption).foregroundStyle(.secondary)}
            if run.isShortestSolution{Label("Shortest route",systemImage:"rosette").font(.caption).foregroundStyle(Palette.ink)}
        }.padding(.vertical,4)
    }
}
// A saved value, independent of TrailStore.run: viewing/sharing never starts or edits a run.
struct CompletedAttemptView:View {
    let run:Run
    @State private var sharing=false
    var body:some View {
        ScrollView{VStack(alignment:.leading,spacing:20){
            Label("Completed trail",systemImage:"checkmark.seal.fill").font(.title2)
            Text("\(run.puzzle.start) to \(run.puzzle.goal)").font(.system(.largeTitle,design:.serif))
            Text(run.scoreDescription).font(.title2.weight(.semibold)).foregroundStyle(Palette.ink).accessibilityIdentifier("savedParResult")
            if run.isShortestSolution{ShortestRouteAcknowledgement()}
            Text("\(run.moves) steps · Par \(run.puzzle.par) · Minimum \(run.puzzle.minimum)").font(.headline)
            if let date=run.finishedAt{Text(date,format:.dateTime.day().month().year().hour().minute()).foregroundStyle(.secondary)}
            Text("\(run.hints) hints · \(run.totalMoves) submitted steps").font(.subheadline).foregroundStyle(.secondary)
            Button("Share your result",systemImage:"square.and.arrow.up"){sharing=true}.buttonStyle(TrailButton()).accessibilityIdentifier("shareSavedResult")
            Text("Your saved attempt, with its original par and minimum.").font(.caption).foregroundStyle(.secondary)
            ForEach(Array(run.chain.enumerated()),id:\.offset){index,word in
                VStack(spacing:8){
                    if index>0{Image(systemName:"arrow.down").font(.caption).foregroundStyle(.secondary)}
                    WordTiles(word:word,previous:index>0 ? run.chain[index-1]:nil)
                }
            }
        }.padding(20).trailReadableWidth()}.background(Palette.canvas).navigationTitle("Your completed trail").navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented:$sharing){ResultShareView(run:run)}
    }
}
