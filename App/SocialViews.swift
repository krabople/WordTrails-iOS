import SwiftUI
import GameKit
import TrailCore

struct FriendsView: View {
    @EnvironmentObject private var social: GameCenterService
    @State private var mode: PlayMode = .coop
    @State private var length = 4
    @State private var onlinePlay = false
    var body: some View {
        List {
            Section {
                Text("Better together.").font(.system(.largeTitle,design:.serif))
                Text("Invite a friend through Game Center, or find a partner. Prefer to start straight away? Pip, Fern and Oak are always on the Trails tab.").foregroundStyle(.secondary)
            }.listRowBackground(Color.clear)
            if !social.authenticated {
                Section { Button("Sign in to Game Center",systemImage:"person.crop.circle") { social.signIn() }; Text("Use your Apple Game Center profile. Word Trails never asks for your Apple password or uploads your address book.").font(.caption) }
            } else {
                Section("Your trail circle") {
                    Label(GKLocalPlayer.local.displayName,systemImage:"person.crop.circle.fill")
                    Button("Add a friend",systemImage:"person.badge.plus") { social.addFriend() }
                    Button("Load Game Center friends",systemImage:"person.2") { Task { await social.loadFriends() } }.disabled(social.loadingFriends)
                    ForEach(social.friends,id:\.gamePlayerID) { friend in Label(friend.displayName,systemImage:"person.crop.circle") }
                    Text("Friend requests open Apple’s Messages sheet. You choose the recipient and send the invitation. Invite accepted friends from the match picker.").font(.caption).foregroundStyle(.secondary)
                }
                Section("New human match") {
                    Picker("Mode",selection:$mode) { Text("Co-op").tag(PlayMode.coop); Text("Versus").tag(PlayMode.versus) }.pickerStyle(.segmented)
                    Picker("Letters",selection:$length) { ForEach(3...6,id:\.self) { Text("\($0) letters").tag($0) } }
                    Text(mode == .coop ? "Take turns adding one word to a shared trail. Both players finish together. No hints or undo in online matches." : "Each player solves the same trail on their own turn. Fewest letter changes wins; a tie is a draw. Routes stay hidden until both finish. No timer, hints or undo.").font(.subheadline).foregroundStyle(.secondary)
                    Button("Invite or find a player",systemImage:"plus.circle") { social.matchmaking(mode:mode,length:length) }.disabled(social.busy)
                }
                Section("Your matches") {
                    Button("Refresh matches",systemImage:"arrow.clockwise") { Task { await social.refresh() } }.disabled(social.busy)
                    if social.matches.isEmpty { Text("No matches yet. Start with a friend, or play with a bot while the community grows.").foregroundStyle(.secondary) }
                    ForEach(social.matches,id:\.matchID) { match in
                        Button { Task { await social.open(match); onlinePlay = social.selected?.matchID == match.matchID } } label: {
                            HStack { VStack(alignment:.leading) { Text(match.participants.compactMap(\.player).filter {$0.gamePlayerID != social.localID}.map(\.displayName).joined(separator:", ").isEmpty ? "Finding a player" : match.participants.compactMap(\.player).filter {$0.gamePlayerID != social.localID}.map(\.displayName).joined(separator:", ")); Text(match.status == .ended ? "Complete" : match.currentParticipant?.player?.gamePlayerID == social.localID ? "Your turn" : "Waiting for your friend").font(.caption).foregroundStyle(.secondary) }; Spacer(); Image(systemName:"chevron.right") }
                        }.disabled(social.busy)
                    }
                    Text("Manage invitations and forfeit matches in Apple’s match picker. Match data and notifications are handled by Game Center.").font(.caption).foregroundStyle(.secondary)
                }
            }
            if let error = social.error { Section { Text(error).foregroundStyle(.secondary) } }
            Section("Trail guides · Bots") {
                ForEach(Guide.allCases) { guide in HStack { Image(systemName:guide.symbol).font(.title2).frame(width:38); VStack(alignment:.leading) { Text("\(guide.name) · Bot").font(.headline); Text(guide.caption).font(.caption).foregroundStyle(.secondary) } } }
                Text("Guides run on your device. They are never shown as human accounts or included in human matchmaking.").font(.caption).foregroundStyle(.secondary)
            }
        }.navigationTitle("Together")
        .sheet(isPresented:$social.showMatchmaker) { Matchmaker(service:social) }
        .navigationDestination(isPresented:$onlinePlay) { OnlinePlayView() }
        .onChange(of:social.selected?.matchID) { _,value in onlinePlay = value != nil }
        .refreshable { await social.refresh() }
    }
}

struct OnlinePlayView: View {
    @EnvironmentObject private var social: GameCenterService
    @EnvironmentObject private var store: TrailStore
    @State private var input = ""
    @State private var leaving = false
    var body: some View {
        ScrollView { VStack(alignment:.leading,spacing:18) {
            if let state = social.state, let run = social.myRun {
                Text("\(state.puzzle.start) to \(state.puzzle.goal)").font(.system(.largeTitle,design:.serif))
                Text("\(state.mode.title) · Par \(state.puzzle.par) · \(run.moves) steps").foregroundStyle(.secondary)
                ForEach(Array(run.chain.enumerated()),id:\.offset) { i,word in WordTiles(word:word,previous:i > 0 ? run.chain[i-1] : nil,active:i == run.chain.count-1) }
                if social.selected?.status == .ended {
                    Label(run.isComplete ? "Trail complete" : "Match ended",systemImage:run.isComplete ? "checkmark.seal" : "flag").font(.title2)
                    if !run.isComplete { Text("A player left before this trail was finished.").foregroundStyle(.secondary) }
                    if state.mode == .versus, let mine = state.racers[social.localID], mine.isComplete,
                       let other = state.racers.first(where:{$0.key != social.localID})?.value, other.isComplete {
                        Text(mine.moves < other.moves ? "You won!" : mine.moves == other.moves ? "A shared summit" : "Your friend won").font(.title2)
                    }
                    if state.mode == .versus { ForEach(Array(state.racers.keys.sorted()),id:\.self) { id in if let result = state.racers[id] { Text("\(id == social.localID ? "You" : "Your friend"): \(result.moves) steps").font(.headline); Text(result.chain.joined(separator:" → ")).font(.system(.subheadline,design:.monospaced)) } } }
                } else if run.isComplete { Text("Your route is submitted. Waiting for your friend to finish.") }
                else if social.myTurn {
                    TextField("Next \(run.puzzle.length)-letter word",text:$input).textFieldStyle(.roundedBorder).textInputAutocapitalization(.characters).autocorrectionDisabled().keyboardType(.asciiCapable).submitLabel(.go).onSubmit(submit)
                    Button("Send step",action:submit).buttonStyle(TrailButton()).disabled(social.busy || input.isEmpty)
                } else { Label("Your friend’s turn",systemImage:"hourglass"); Text("Game Center will let you know when your turn is ready.").foregroundStyle(.secondary) }
                if let error = social.error { Text(error).foregroundStyle(.secondary) }
                Button("Refresh",systemImage:"arrow.clockwise") { Task { if let match = social.selected { await social.open(match); social.syncCompleted(into:store) } } }.disabled(social.busy)
            }
        }.padding(20) }.navigationTitle("Shared trail").navigationBarTitleDisplayMode(.inline)
        .task { social.syncCompleted(into:store) }
        .toolbar { if social.selected?.status == .open { Button("Leave",role:.destructive) { leaving = true }.disabled(social.busy) } }
        .confirmationDialog("Leave this match? This counts as a forfeit.",isPresented:$leaving,titleVisibility:.visible) {
            Button("Leave match",role:.destructive) { Task { if let match = social.selected { await social.forfeit(match); await social.refresh() } } }
            Button("Keep playing",role:.cancel) {}
        }
        .onChange(of:social.selected?.status) { _,_ in social.syncCompleted(into:store) }
    }
    private func submit() { Task { await social.submit(input,progress:store); if social.error == nil { input = "" } } }
}
