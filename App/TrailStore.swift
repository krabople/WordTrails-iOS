import SwiftUI
import TrailCore

@MainActor final class TrailStore: ObservableObject {
    @Published var progress = TrailCore.Progress()
    @Published var run: Run?
    @Published var message = ""
    @Published var awarded = 0
    @Published var busy = false
    @Published var showWelcome = !UserDefaults.standard.bool(forKey: "welcomed")
    @Published var persistenceError: String?
    @Published var showRecoveryWarning = false
    private let url: URL
    init() {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("WordTrails", isDirectory: true)
        let testing = ProcessInfo.processInfo.arguments.contains("--ui-test")
        url = directory.appendingPathComponent(testing ? "uitest-\(UUID().uuidString).json" : "progress-v1.json")
        if testing { showWelcome = true }
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            if FileManager.default.fileExists(atPath: url.path) {
                let saved = try JSONDecoder().decode(Saved.self, from: Data(contentsOf: url))
                progress = saved.progress; run = saved.run
            }
        } catch { persistenceError = "Your saved progress couldn’t be opened. It has been kept on this device. \(error.localizedDescription)"; showRecoveryWarning = true }
        #if DEBUG
        if testing && ProcessInfo.processInfo.arguments.contains("--example-trail") {
            let coop = ProcessInfo.processInfo.arguments.contains("--example-coop")
            run = Run(puzzle:Puzzle(id:"CAT-DOG",start:"CAT",goal:"DOG",par:3),mode:coop ? .coop : .solo,guide:coop ? .oak : nil)
            showWelcome = false
        }
        #endif
    }
    struct Saved: Codable { var progress: TrailCore.Progress; var run: Run? }
    func save() {
        guard persistenceError == nil else { return }
        do { try JSONEncoder().encode(Saved(progress: progress, run: run)).write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication]) }
        catch { message = "Progress couldn’t be saved: \(error.localizedDescription)" }
    }
    func start(_ puzzle: Puzzle, mode: PlayMode, guide: Guide?, daily: Bool) {
        run = Run(puzzle: puzzle, mode: mode, guide: guide, daily: daily)
        message = ""; awarded = 0; save()
    }
    func submit(_ word: String) {
        guard !busy, var next = run else { return }
        if next.mode == .coop && next.guide != nil && !next.moves.isMultiple(of:2) { takeBotTurn(); return }
        do {
            try next.submit(word)
            run = next; message = ""; save()
            finishIfNeeded()
            if next.mode == .coop && !next.isComplete { takeBotTurn() }
        } catch { message = error.localizedDescription; UIAccessibility.post(notification: .announcement, argument: message) }
    }
    func takeBotTurn() {
        guard let current = run, current.mode == .coop, current.guide != nil, !current.isComplete else { return }
        busy = true
        Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(650))
            guard let self else { return }
            defer { self.busy = false }
            guard var next = self.run, next.id == current.id else { return }
            do {
                if next.nextHint() == nil { self.message = "This path is blocked. Undo your last step to find another route."; return }
                try next.guideStep(); self.run = next; self.save(); self.finishIfNeeded()
            } catch { self.message = error.localizedDescription }
        }
    }
    func finishIfNeeded() {
        guard let run, run.isComplete else { return }
        awarded = progress.record(run); save()
    }
    func undo() {
        guard !busy, var next = run else { return }
        if next.mode == .coop && next.guide != nil && next.moves >= 2 && next.moves.isMultiple(of:2) { next.undo() }
        next.undo(); run = next; message = ""; save()
    }
    func hint() {
        guard !busy, var next = run, !next.isComplete, next.mode != .versus else { return }
        if let hint = next.nextHint() {
            next.hints += 1; run = next; message = "Try \(hint). Hints turn off the perfect-route reward."; save()
        } else { message = "No forward path from here. Undo a step to rejoin the trail." }
    }
    func plant(_ id: String) { if progress.plant(id) { save() } }
    func welcome() { showWelcome = false; UserDefaults.standard.set(true, forKey: "welcomed") }
}
