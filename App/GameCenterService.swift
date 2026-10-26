import SwiftUI
import GameKit
import TrailCore

enum SocialError: LocalizedError {
    case invalid, notTurn, unavailable, full
    var errorDescription: String? { switch self {
    case .invalid: "This match uses unsupported or invalid game data. Update the app or start a new match."
    case .notTurn: "It’s your friend’s turn. Refresh to check for their next step."
    case .unavailable: "Sign in to Game Center to play online. Solo trails are always available."
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
    private var authenticatedPlayerID: String?
    var newPuzzle: Puzzle = TrailCatalog.daily(length:4)
    var localID: String { GKLocalPlayer.local.gamePlayerID }
    var myTurn: Bool { selected?.status == .open && selected?.currentParticipant?.player?.gamePlayerID == localID }
    var myRun: Run? { state?.coop }
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
                let identity = self.authenticated ? GKLocalPlayer.local.gamePlayerID : nil
                if identity != self.authenticatedPlayerID {
                    self.friends = []; self.matches = []; self.selected = nil; self.state = nil
                    self.authenticatedPlayerID = identity
                }
                if let failure { self.error = failure.localizedDescription }
                if self.authenticated { GKLocalPlayer.local.register(self); await self.refresh() }
            }
        }
    }
    func refresh() async {
        guard authenticated else { return }
        let identity = localID
        busy = true; defer { busy = false }
        do { let loaded = try await GKTurnBasedMatch.loadMatches().sorted { $0.creationDate > $1.creationDate }; if authenticated && identity == localID { matches = loaded.filter { match in guard let data=match.matchData,!data.isEmpty else{return true};return (try? JSONDecoder().decode(SharedTrail.self,from:data))?.mode == .coop } } }
        catch { self.error = error.localizedDescription }
    }
    func loadFriends() async {
        guard authenticated else { error = SocialError.unavailable.localizedDescription; return }
        let identity = localID
        loadingFriends = true; defer { loadingFriends = false }
        do { let loaded = try await GKLocalPlayer.local.loadFriends(); if authenticated && identity == localID { friends = loaded } }
        catch { self.error = error.localizedDescription }
    }
    func addFriend() {
        guard authenticated, let vc = Self.presenter else { error = SocialError.unavailable.localizedDescription; return }
        do { try GKLocalPlayer.local.presentFriendRequestCreator(from:vc) } catch { self.error = error.localizedDescription }
    }
    func matchmaking(length: Int) {
        guard authenticated else { error = SocialError.unavailable.localizedDescription; return }
        newPuzzle = TrailCatalog.puzzles(length:length).randomElement()!
        showMatchmaker = true
    }
    func open(_ match: GKTurnBasedMatch) async {
        let identity = localID
        busy = true; defer { busy = false }
        do {
            // Always reload before showing a match; the inbox can contain older snapshots.
            let fresh = try await GKTurnBasedMatch.load(withID:match.matchID)
            guard authenticated, identity == localID else { throw SocialError.unavailable }
            var content: SharedTrail
            if let data = fresh.matchData, !data.isEmpty { content = try JSONDecoder().decode(SharedTrail.self,from:data) }
            else {
                guard fresh.currentParticipant?.player?.gamePlayerID == localID else { throw SocialError.notTurn }
                content = SharedTrail(puzzle:newPuzzle)
                try await fresh.saveCurrentTurn(withMatch:JSONEncoder().encode(content))
            }
            try content.validate()
            let opponents = fresh.participants.filter {$0.player?.gamePlayerID != localID}
            if fresh.status == .open, fresh.currentParticipant?.player?.gamePlayerID == localID,
               !opponents.isEmpty, opponents.allSatisfy({$0.status == .done || $0.status == .declined}) {
                for participant in fresh.participants {
                    if participant.player?.gamePlayerID == localID { participant.matchOutcome = .won }
                    else if participant.matchOutcome == .none { participant.matchOutcome = .quit }
                }
                try await fresh.endMatchInTurn(withMatch:JSONEncoder().encode(content))
            }
            selected = fresh; state = content; error = nil
        } catch { self.error = error.localizedDescription }
    }
    func submit(_ word: String, progress: TrailStore) async {
        guard !busy, let selected, let original = state else { return }
        let submittingPlayer = localID
        busy = true; defer { busy = false }
        do {
            let fresh = try await GKTurnBasedMatch.load(withID:selected.matchID)
            guard authenticated, localID == submittingPlayer else { throw SocialError.unavailable }
            guard fresh.status == .open, fresh.currentParticipant?.player?.gamePlayerID == localID else { throw SocialError.notTurn }
            guard let data = fresh.matchData else { throw SocialError.invalid }
            var next = try JSONDecoder().decode(SharedTrail.self,from:data); try next.validate()
            // Never overwrite a newer server version with a stale local turn.
            guard next.version == original.version, next.puzzle == original.puzzle, next.coop.chain == original.coop.chain else {
                state = next; self.selected = fresh; throw SocialError.notTurn
            }
            try next.coop.submit(word,lexicon:next.lexicon)
            let finished = next.coop.isComplete
            let encoded = try JSONEncoder().encode(next)
            guard encoded.count <= fresh.matchDataMaximumSize else { throw SocialError.invalid }
            let others = fresh.participants.filter { $0.player?.gamePlayerID != localID && $0.status != .declined && $0.status != .done }
            guard !others.isEmpty else { throw SocialError.full }
            fresh.message = "Your next step on the co-op trail is ready."
            if finished {
                for participant in fresh.participants { participant.matchOutcome = .won }
                try await fresh.endMatchInTurn(withMatch:encoded)
            } else {
                try await fresh.endTurn(withNextParticipants:others,turnTimeout:GKTurnTimeoutDefault,match:encoded)
            }
            guard authenticated, localID == submittingPlayer else { throw SocialError.unavailable }
            self.selected = fresh; state = next; error = nil
            progress.progress.track(next.coop)
            if finished { record(next.coop,in:progress,state:next) } else { progress.save() }
        } catch { self.error = error.localizedDescription }
    }
    func record(_ run: Run, in store: TrailStore, state: SharedTrail) {
        store.progress.record(run)
        if state.mode == .coop, let match = selected, let friend = match.participants.compactMap(\.player).first(where:{$0.gamePlayerID != localID}) {
            store.progress.rememberGarden(id:friend.gamePlayerID,name:friend.displayName,trailID:run.id.uuidString)
        }
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
    func forfeit(_ match: GKTurnBasedMatch) async {
        guard authenticated, !busy else { return }
        let identity = localID
        busy = true; defer { busy = false }
        do {
            let fresh = try await GKTurnBasedMatch.load(withID:match.matchID)
            guard authenticated, identity == localID, fresh.status == .open else { throw SocialError.unavailable }
            let data = fresh.matchData ?? Data()
            if fresh.currentParticipant?.player?.gamePlayerID == localID {
                let others = fresh.participants.filter {$0.player?.gamePlayerID != localID && $0.status != .done && $0.status != .declined}
                if others.isEmpty {
                    for participant in fresh.participants where participant.matchOutcome == .none { participant.matchOutcome = .quit }
                    try await fresh.endMatchInTurn(withMatch:data)
                } else {
                    try await withCheckedThrowingContinuation { (continuation:CheckedContinuation<Void,Error>) in
                        fresh.participantQuitInTurn(with:.quit,nextParticipants:others,turnTimeout:GKTurnTimeoutDefault,match:data) { failure in
                            if let failure { continuation.resume(throwing:failure) } else { continuation.resume() }
                        }
                    }
                }
            } else {
                try await withCheckedThrowingContinuation { (continuation:CheckedContinuation<Void,Error>) in
                    fresh.participantQuitOutOfTurn(with:.quit) { failure in
                        if let failure { continuation.resume(throwing:failure) } else { continuation.resume() }
                    }
                }
            }
            if selected?.matchID == match.matchID { selected = nil; state = nil }
            error = nil
        } catch { self.error = error.localizedDescription }
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
        // Dictionary v2 uses a separate pool; existing v1 co-op matches retain v1 rules.
        request.playerGroup = 2100 + service.newPuzzle.length
        let controller = GKTurnBasedMatchmakerViewController(matchRequest:request)
        controller.turnBasedMatchmakerDelegate = context.coordinator
        controller.showExistingMatches = false
        return controller
    }
    func updateUIViewController(_ uiViewController:GKTurnBasedMatchmakerViewController,context:Context) {}
    @MainActor final class Coordinator: NSObject, GKTurnBasedMatchmakerViewControllerDelegate {
        let service: GameCenterService
        init(_ service:GameCenterService) { self.service = service }
        nonisolated func turnBasedMatchmakerViewControllerWasCancelled(_ viewController:GKTurnBasedMatchmakerViewController) { Task { @MainActor in service.showMatchmaker = false } }
        nonisolated func turnBasedMatchmakerViewController(_ viewController:GKTurnBasedMatchmakerViewController,didFailWithError error:Error) { Task { @MainActor in service.showMatchmaker = false; service.error = error.localizedDescription } }
        nonisolated func turnBasedMatchmakerViewController(_ viewController:GKTurnBasedMatchmakerViewController,didFind match:GKTurnBasedMatch) { Task { @MainActor in service.showMatchmaker = false; await service.open(match) } }
        nonisolated func turnBasedMatchmakerViewController(_ viewController:GKTurnBasedMatchmakerViewController,playerQuitFor match:GKTurnBasedMatch) { Task { @MainActor in await service.forfeit(match); await service.refresh() } }
    }
}
