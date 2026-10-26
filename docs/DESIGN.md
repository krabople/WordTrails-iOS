# Word Trails 1.3 design

The primary experience is a daily solo trail, with four letter lengths and optional practice. No opponent or account is required. Optional Game Center co-op lets two real players alternate legal words on a shared route. Bots and versus have been removed.

Change exactly one letter, retain the length and use an accepted word. No repeated words; steps that would trap the player are rejected. Solo includes hints and undo. Co-op is turn based without either aid.

The comprehensive ESDB dictionary contains 37,819 accepted 3–6-letter forms. All 40,000 catalog trails have a shortest route using the frequency-screened familiar-word list, and the full dictionary has exactly the same shortest distance. Each difficulty has 10,000 unordered endpoint pairs. Minimum steps are at least 4, 5, 6 and 7 respectively. Par allows one extra step for 3–4 letters and two for 5–6 letters. This is a difficulty heuristic; later player evidence could inform recalibration.

Statistics distinguish attempts from completions and use run IDs to avoid double counting resumed games. Per difficulty and overall they show completion rates, below/on/above-par counts, shortest routes, average steps and average/best score against par. Old completed trails are imported with their original par; earlier abandoned attempts were not saved and cannot be recovered.

Daily notifications are disabled by default. The player chooses a local time and explicitly grants iOS permission. A single repeating calendar notification replaces its previous schedule when edited. These reminders require no server or internet. Game Center turn alerts remain Apple's separate multiplayer feature.

The first completion of each trail/mode earns three seeds, plus two for finishing at or below par without hints. Six plants cost ten seeds each; 24 badges reward progress. Replays count in statistics but cannot farm seeds. Friend co-op results grow shared milestone gardens. Existing earned local progress is preserved; removed bot gardens and the versus badge are retired.

Version-1 co-op packets keep the original dictionary and par. New matchmaking uses a separate version-2 pool. The service reloads the server match before writing, validates the packet, confirms turn ownership and refuses stale state. Invitations and friendships use native Game Center UI. No website, separate backend, contacts upload, analytics or chat is involved.

Original code-drawn landscapes, restrained botanical geometry, system type and SF Symbols avoid generated artwork artifacts. Dark mode, VoiceOver, Dynamic Type and scrolling layouts are supported. Personal progress remains on-device. Two-device Game Center behavior and physical-device notification delivery remain beta validation tasks.

Hints search the full graph with future nodes restricted to familiar words, allowing an unusual current word as the starting node. They choose that familiar route whenever its distance equals the shortest full-dictionary distance. Only an unavoidable difference triggers an uncommon continuation. The actual hint stays short; Field notes explains this rule.

Badges include 100, 250, 500 and 1,000 rewarded trails; 30, 100 and 365 daily-play days; 90- and 365-day streaks; distinct under-par and shortest-route totals; 25 trails per difficulty; a full garden; and co-op milestones. New awards are announced together. Replayed copies of the same puzzle/mode do not inflate distinct-route achievements. Historical longest streaks are retained through the existing daily-day history.

Result sharing renders an original native vector card at 1200×1560. It shows the endpoints, score, steps, par, minimum and hint status, without intermediate-word spoilers. The system activity sheet shares the PNG and canonical App Store URL. That URL becomes live when the app is publicly released.

Completed results are immutable Run values rendered independently from TrailStore.run. A saved view does not call start, submit, record or track. Daily cards select the latest matching solo completion, checking both puzzle ID and endpoints for compatibility with older catalogs; every older result remains available in the full searchable history. Stats also links directly to history, while recent rows open the same detail view.

The shortest-route acknowledgement requires a completed route whose step count equals that attempt's stored minimum. It recognises minimum length even with hints or undo; the unassisted badges retain their separate requirements. The marker appears in live completion, saved detail, co-op completion and the rendered share card.
