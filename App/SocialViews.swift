import SwiftUI
import GameKit
import TrailCore

struct FriendsView:View {
    @EnvironmentObject private var social:GameCenterService
    @State private var length=4
    @State private var onlinePlay=false
    var body:some View {
        List{
            Section{
                Text("A trail together.").font(.system(.largeTitle,design:.serif))
                Text("An optional shared puzzle with a friend. Take turns changing one letter and work towards the same destination. Your daily solo trail is always on the Trails tab.").foregroundStyle(.secondary)
            }.listRowBackground(Color.clear)
            if !social.authenticated{
                Section{Button("Sign in to Game Center",systemImage:"person.crop.circle"){social.signIn()};Text("Solo play works without an account. Game Center is only needed for co-op.").font(.caption)}
            }else{
                Section("Your trail circle"){
                    Label(GKLocalPlayer.local.displayName,systemImage:"person.crop.circle.fill")
                    Button("Add a friend",systemImage:"person.badge.plus"){social.addFriend()}
                    Button("Load Game Center friends",systemImage:"person.2"){Task{await social.loadFriends()}}.disabled(social.loadingFriends)
                    ForEach(social.friends,id:\.gamePlayerID){friend in Label(friend.displayName,systemImage:"person.crop.circle")}
                    Text("Friend requests open Apple’s Messages sheet. Choose a recipient and send the invitation, then invite accepted friends from the match picker.").font(.caption).foregroundStyle(.secondary)
                }
                Section("Start a co-op trail"){
                    Picker("Letters",selection:$length){ForEach(3...6,id:\.self){Text("\($0) letters").tag($0)}}
                    Text("Take turns adding one word. Both players share the route and score against par. No hints or undo in online trails.").font(.subheadline).foregroundStyle(.secondary)
                    Button("Invite or find a partner",systemImage:"plus.circle"){social.matchmaking(length:length)}.disabled(social.busy)
                }
                Section("Your co-op trails"){
                    Button("Refresh trails",systemImage:"arrow.clockwise"){Task{await social.refresh()}}.disabled(social.busy)
                    if social.matches.isEmpty{Text("No shared trails yet. Invite a friend whenever you’d like company.").foregroundStyle(.secondary)}
                    ForEach(social.matches,id:\.matchID){match in
                        Button{Task{await social.open(match);onlinePlay=social.selected?.matchID==match.matchID}}label:{
                            HStack{VStack(alignment:.leading){
                                Text(partnerName(match))
                                Text(match.status == .ended ? "Complete":match.currentParticipant?.player?.gamePlayerID==social.localID ? "Your turn":"Waiting for your friend").font(.caption).foregroundStyle(.secondary)
                            };Spacer();Image(systemName:"chevron.right")}
                        }.disabled(social.busy)
                    }
                    Text("Match data and turn alerts are handled by Game Center. You can leave a trail using the Leave button inside it.").font(.caption).foregroundStyle(.secondary)
                }
            }
            if let error=social.error{Section{Text(error).foregroundStyle(.secondary)}}
        }.trailListWidth().navigationTitle("Co-op")
        .sheet(isPresented:$social.showMatchmaker){Matchmaker(service:social)}
        .navigationDestination(isPresented:$onlinePlay){OnlinePlayView()}
        .onChange(of:social.selected?.matchID){_,value in onlinePlay=value != nil}
        .refreshable{await social.refresh()}
    }
    private func partnerName(_ match:GKTurnBasedMatch)->String {
        let names=match.participants.compactMap(\.player).filter{$0.gamePlayerID != social.localID}.map(\.displayName).joined(separator:", ")
        return names.isEmpty ? "Finding a partner":names
    }
}
struct OnlinePlayView:View {
    @EnvironmentObject private var social:GameCenterService
    @EnvironmentObject private var store:TrailStore
    @State private var input=""
    @State private var leaving=false
    var body:some View {
        ScrollView{VStack(alignment:.leading,spacing:18){
            if let state=social.state,let run=social.myRun {
                Text("\(state.puzzle.start) to \(state.puzzle.goal)").font(.system(.largeTitle,design:.serif))
                Text("Co-op · Par \(state.puzzle.par) · \(run.moves) steps").foregroundStyle(.secondary)
                if state.version==1{Text("This saved trail keeps its original dictionary and par. Start a new co-op trail to use the expanded dictionary.").font(.caption).foregroundStyle(.secondary)}
                ForEach(Array(run.chain.enumerated()),id:\.offset){i,word in WordTiles(word:word,previous:i>0 ? run.chain[i-1]:nil,active:i==run.chain.count-1)}
                if social.selected?.status == .ended {
                    Label(run.isComplete ? "Trail complete":"Trail ended",systemImage:run.isComplete ? "checkmark.seal":"flag").font(.title2)
                    if run.isComplete{if run.isShortestSolution{ShortestRouteAcknowledgement()};Text("Together: \(run.scoreDescription.lowercased())").font(.title2)}
                    else{Text("A player left before this trail was finished.").foregroundStyle(.secondary)}
                }else if social.myTurn{
                    TextField("Next \(run.puzzle.length)-letter word",text:$input).textFieldStyle(.roundedBorder).textInputAutocapitalization(.characters).autocorrectionDisabled().keyboardType(.asciiCapable).submitLabel(.go).onSubmit(submit)
                    Button("Send step",action:submit).buttonStyle(TrailButton()).disabled(social.busy || input.isEmpty)
                }else{Label("Your friend’s turn",systemImage:"hourglass");Text("Game Center will let you know when your turn is ready.").foregroundStyle(.secondary)}
                if let error=social.error{Text(error).foregroundStyle(.secondary)}
                Button("Refresh",systemImage:"arrow.clockwise"){Task{if let match=social.selected{await social.open(match);social.syncCompleted(into:store)}}}.disabled(social.busy)
            }
        }.padding(20)}.navigationTitle("Shared trail").navigationBarTitleDisplayMode(.inline)
        .task{if let run=social.myRun{store.progress.track(run);store.save()};social.syncCompleted(into:store)}
        .toolbar{if social.selected?.status == .open{Button("Leave",role:.destructive){leaving=true}.disabled(social.busy)}}
        .confirmationDialog("Leave this shared trail?",isPresented:$leaving,titleVisibility:.visible){
            Button("Leave trail",role:.destructive){Task{if let match=social.selected{await social.forfeit(match);await social.refresh()}}}
            Button("Keep playing",role:.cancel){}
        }
        .onChange(of:social.selected?.status){_,_ in social.syncCompleted(into:store)}
    }
    private func submit(){Task{await social.submit(input,progress:store);if social.error==nil{input=""}}}
}
