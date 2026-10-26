import SwiftUI
import GameKit
import TrailCore

struct SharedTrail: Codable {
    var version = 1
    var mode: PlayMode
    var puzzle: Puzzle
    var coop: Run
    var racers: [String: Run] = [:]
    func validate() throws {
        guard version == 1, mode != .solo,
              TrailCatalog.all.contains(where: { $0.start == puzzle.start && $0.goal == puzzle.goal && $0.par == puzzle.par }),
              coop.puzzle == puzzle, coop.isValid(), coop.mode == .coop, coop.guide == nil, coop.hints == 0, racers.count <= 2,
              Set(racers.values.map(\.id)).count == racers.count,
              racers.values.allSatisfy({$0.puzzle == puzzle && $0.mode == .versus && $0.guide == nil && $0.isValid() && $0.hints == 0}) else { throw SocialError.invalid }
    }
}
enum SocialError: LocalizedError {
    case invalid, notTurn, unavailable, full
    var errorDescription: String? { switch self {
    case .invalid: "This match uses unsupported or invalid game data. Update the app or start a new match."
    case .notTurn: "It’s your friend’s turn. Refresh to check for their next step."
    case .unavailable: "Sign in to Game Center to play online. Solo and bot trails are always available."
    case .full: "This match has no other active player. You can leave it from Game Center and start a new trail."
    } }
}

@MainActor final class GameCenterService: NSObject, ObservableObject, GKLocalPlayerListener {
    @Published var authenticated = false
    @Published var friends: [GKPlayer] = []
    @Published var matches: [GKTurnBasedMatch] = []
    @Published var selected: GKTurnBasedMatch?
    @Published var state: SharedTrail?
    @Published var error: String?
    @Published var busy = false
    @Published var loadingFriends = false
    @Published var showMatchmaker = false
    var newMode: PlayMode = .coop
    var newPuzzle: Puzzle = TrailCatalog.daily(length:4)
    var localID: String { GKLocalPlayer.local.gamePlayerID }
    var myTurn: Bool { selected?.status == .open && selected?.currentParticipant?.player?.gamePlayerID == localID }
    var myRun: Run? { guard let state else { return nil }; return state.mode == .coop ? state.coop : state.racers[localID] ?? Run(puzzle:state.puzzle,mode:.versus) }
    static var presenter: UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap {$0 as? UIWindowScene}
        var vc = scenes.flatMap(\.windows).first(where: \.isKeyWindow)?.rootViewController
        while let presented = vc?.presentedViewController { vc = presented }
        return vc
    }
    func signIn() {
        GKLocalPlayer.local.authenticateHandler = { [weak self] vc, failure in
            Task { @MainActor in
                guard let self else { return }
                if let vc { Self.presenter?.present(vc,animated:true); return }
                self.authenticated = GKLocalPlayer.local.isAuthenticated
                if let failure { self.error = failure.localizedDescription }
                if self.authenticated { GKLocalPlayer.local.register(self); await self.refresh() }
            }
        }
    }
    func refresh() async {
        guard authenticated else { return }
        busy = true; defer { busy = false }
        do { matches = try await GKTurnBasedMatch.loadMatches().sorted { $0.creationDate > $1.creationDate } }
        catch { self.error = error.localizedDescription }
    }
    func loadFriends() async {
        guard authenticated else { error = SocialError.unavailable.localizedDescription; return }
        loadingFriends = true; defer { loadingFriends = false }
        do { friends = try await GKLocalPlayer.local.loadFriends() }
        catch { self.error = error.localizedDescription }
    }
    func addFriend() {
        guard authenticated, let vc = Self.presenter else { error = SocialError.unavailable.localizedDescription; return }
        do { try GKLocalPlayer.local.presentFriendRequestCreator(from:vc) } catch { self.error = error.localizedDescription }
    }
    func matchmaking(mode: PlayMode, length: Int) {
        guard authenticated else { error = SocialError.unavailable.localizedDescription; return }
        newMode = mode; newPuzzle = TrailCatalog.all.filter {$0.length == length}.randomElement()!
        showMatchmaker = true
    }
    func open(_ match: GKTurnBasedMatch) async {
        busy = true; defer { busy = false }
        do {
            // Always reload before showing a match; the inbox can contain older snapshots.
            let fresh = try await GKTurnBasedMatch.load(withID:match.matchID)
            var content: SharedTrail
            if let data = fresh.matchData, !data.isEmpty { content = try JSONDecoder().decode(SharedTrail.self,from:data) }
            else {
                guard fresh.currentParticipant?.player?.gamePlayerID == localID else { throw SocialError.notTurn }
                content = SharedTrail(mode:newMode,puzzle:newPuzzle,coop:Run(puzzle:newPuzzle,mode:.coop))
                if newMode == .versus { content.racers[localID] = Run(puzzle:newPuzzle,mode:.versus) }
                try await fresh.saveCurrentTurn(withMatch:JSONEncoder().encode(content))
            }
            try content.validate()
            selected = fresh; state = content; error = nil
        } catch { self.error = error.localizedDescription }
    }
    func submit(_ word: String, progress: TrailStore) async {
        guard !busy, let selected, let original = state else { return }
        busy = true; defer { busy = false }
        do {
            let fresh = try await GKTurnBasedMatch.load(withID:selected.matchID)
            guard fresh.status == .open, fresh.currentParticipant?.player?.gamePlayerID == localID else { throw SocialError.notTurn }
            guard let data = fresh.matchData else { throw SocialError.invalid }
            var next = try JSONDecoder().decode(SharedTrail.self,from:data); try next.validate()
            // Never overwrite a newer server version with a stale local turn.
            guard next.coop.chain == original.coop.chain, next.racers.mapValues(\.chain) == original.racers.mapValues(\.chain) else {
                state = next; self.selected = fresh; throw SocialError.notTurn
            }
            var completedRun: Run?
            var finished = false
            if next.mode == .coop {
                try next.coop.submit(word); completedRun = next.coop.isComplete ? next.coop : nil; finished = next.coop.isComplete
            } else {
                var run = next.racers[localID] ?? Run(puzzle:next.puzzle,mode:.versus)
                try run.submit(word); next.racers[localID] = run
                finished = next.racers.count == 2 && next.racers.values.allSatisfy(\.isComplete)
                if finished { completedRun = run }
            }
            let encoded = try JSONEncoder().encode(next)
            guard encoded.count <= fresh.matchDataMaximumSize else { throw SocialError.invalid }
            let others = fresh.participants.filter { $0.player?.gamePlayerID != localID && $0.status != .declined && $0.status != .done }
            guard !others.isEmpty else { throw SocialError.full }
            fresh.message = next.mode == .coop ? "Your next step on the trail is ready." : "Your Word Trails challenge is ready."
            if finished {
                for participant in fresh.participants {
                    if next.mode == .coop { participant.matchOutcome = .won }
                    else if let id = participant.player?.gamePlayerID, let result = next.racers[id] {
                        let other = next.racers.values.first {$0.id != result.id}!
                        participant.matchOutcome = result.moves < other.moves ? .won : result.moves == other.moves ? .tied : .lost
                    }
                }
                try await fresh.endMatchInTurn(withMatch:encoded)
            } else if next.mode == .coop || next.racers[localID]?.isComplete == true {
                try await fresh.endTurn(withNextParticipants:others,turnTimeout:GKTurnTimeoutDefault,match:encoded)
            } else { try await fresh.saveCurrentTurn(withMatch:encoded) }
            self.selected = fresh; state = next; error = nil
            if let run = completedRun { record(run,in:progress,state:next) }
        } catch { self.error = error.localizedDescription }
    }
    func record(_ run: Run, in store: TrailStore, state: SharedTrail) {
        let already = store.progress.completed.contains {$0.id == run.id}
        store.progress.record(run)
        if state.mode == .coop, let match = selected, let friend = match.participants.compactMap(\.player).first(where:{$0.gamePlayerID != localID}) {
            store.progress.rememberGarden(id:friend.gamePlayerID,name:friend.displayName,trailID:run.id.uuidString)
        }
        if !already && state.mode == .versus, let mine = state.racers[localID], let other = state.racers.first(where:{$0.key != localID})?.value, mine.moves < other.moves { store.progress.badges.insert("versus") }
        store.save()
    }
    func syncCompleted(into store: TrailStore) {
        guard let state, selected?.status == .ended else { return }
        if let run = myRun, run.isComplete { record(run,in:store,state:state) }
    }
    func syncGardens(into store: TrailStore) {
        for match in matches where match.status == .ended {
            guard let data = match.matchData, let content = try? JSONDecoder().decode(SharedTrail.self,from:data),
                  (try? content.validate()) != nil, content.mode == .coop, content.coop.isComplete,
                  let friend = match.participants.compactMap(\.player).first(where:{$0.gamePlayerID != localID}) else { continue }
            store.progress.rememberGarden(id:friend.gamePlayerID,name:friend.displayName,trailID:content.coop.id.uuidString)
        }
        store.save()
    }
    nonisolated func player(_ player: GKPlayer, receivedTurnEventFor match: GKTurnBasedMatch, didBecomeActive: Bool) {
        Task { @MainActor in await refresh(); if selected?.matchID == match.matchID || didBecomeActive { await open(match) } }
    }
    nonisolated func player(_ player: GKPlayer, matchEnded match: GKTurnBasedMatch) { Task { @MainActor in await refresh(); if selected?.matchID == match.matchID { await open(match) } } }
}

struct Matchmaker: UIViewControllerRepresentable {
    @ObservedObject var service: GameCenterService
    func makeCoordinator() -> Coordinator { Coordinator(service) }
    func makeUIViewController(context:Context) -> GKTurnBasedMatchmakerViewController {
        let request = GKMatchRequest(); request.minPlayers = 2; request.maxPlayers = 2
        // Keep co-op/versus and word lengths in separate matchmaking pools.
        request.playerGroup = (service.newMode == .coop ? 100 : 200) + service.newPuzzle.length
        let controller = GKTurnBasedMatchmakerViewController(matchRequest:request)
        controller.turnBasedMatchmakerDelegate = context.coordinator
        return controller
    }
    func updateUIViewController(_ uiViewController:GKTurnBasedMatchmakerViewController,context:Context) {}
    @MainActor final class Coordinator: NSObject, GKTurnBasedMatchmakerViewControllerDelegate {
        let service: GameCenterService
        init(_ service:GameCenterService) { self.service = service }
        nonisolated func turnBasedMatchmakerViewControllerWasCancelled(_ viewController:GKTurnBasedMatchmakerViewController) { Task { @MainActor in service.showMatchmaker = false } }
        nonisolated func turnBasedMatchmakerViewController(_ viewController:GKTurnBasedMatchmakerViewController,didFailWithError error:Error) { Task { @MainActor in service.showMatchmaker = false; service.error = error.localizedDescription } }
        nonisolated func turnBasedMatchmakerViewController(_ viewController:GKTurnBasedMatchmakerViewController,didFind match:GKTurnBasedMatch) { Task { @MainActor in service.showMatchmaker = false; await service.open(match) } }
        nonisolated func turnBasedMatchmakerViewController(_ viewController:GKTurnBasedMatchmakerViewController,playerQuitFor match:GKTurnBasedMatch) { Task { @MainActor in await service.refresh() } }
    }
}
