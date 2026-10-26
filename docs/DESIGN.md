# Word Trails: version 1 design

## Promise

A calm, native iPhone word game that is enjoyable with one player on day one. The player's task is always visible: transform the start word into the goal by changing exactly one letter at each step. A step is a change, not a word node. CAT → COT → DOT → DOG takes three steps.

## Content and difficulty

The shipped, browseable dictionary contains 5,090 words. Plurals and inflections are allowed when included. Spaces, hyphens, letter rearrangement, repeated nodes and unlisted words are rejected. The game prevents moving into a branch from which the goal cannot be reached without repeating a visited node. This keeps online and versus games playable without undo.

Meadow has three-letter trails, Woodland four, Highlands five and Summit six. There are 242 precomputed verified trails: 61 three-letter, 61 four-letter and 60 each for five and six letters. Pars are shortest paths in this exact dictionary. The generator and Swift verifier are independent implementations. Word length does not guarantee graph difficulty; trail par is displayed as a second difficulty signal.

Daily puzzles are deterministic for each UTC date and length. Practice selects a catalog trail. The catalog is finite; daily puzzles eventually repeat. No daily content service or subscription is required.

## Modes and a new community

Solo has hints and undo. Daily is solo, so everyone can start immediately. Bot co-op alternates one word with a guide; undo restores the last human turn. Bot versus compares completed route length, with ties drawn and no hints or undo.

Pip, Fern and Oak are persistent bot identities in the app, explicitly labelled **Bot**. They are not fake Game Center accounts. Oak finds a shortest route, Fern permits a small legal detour, and Pip permits a larger detour when the graph allows one. Their routes are deterministic, dictionary-valid and do not repeat words. Guides run on-device and are available offline. Co-op guides respect all previously visited words.

Human co-op alternates word submissions through Game Center. Human versus is asynchronous: player one completes and submits a route, player two completes their own, then both routes and results are shown. Fewest steps wins; equal steps draw. There is no timer that rewards the second player's notification response speed. This is casual play, with no cash prizes, ranked ladder or claim of tamper-proof tournament scoring.

## Friends and invitations

The Together tab explains Apple Game Center before optional sign-in. Players can explicitly load their Game Center friends, open Apple's friend-request creator, invite friends to a match, or use automatching. The request creator opens a Messages sheet; the player chooses a recipient and sends it. Word Trails never uploads contacts or sends unsolicited invitations. Online pools are separated by mode and letter count. Native match management supports invitations and forfeits.

Game Center stores and forwards matches and sends turn events. The client reloads the latest match before a write, validates payloads, checks turn ownership and refuses stale state. A failed network request leaves the visible accepted chain intact; the player can refresh and retry. Completed results are recorded once by run ID. Open matches can be reopened from the inbox after an app restart.

## Rewards and gardens

The first completion of each puzzle/mode earns three seeds, plus two for a route at par without hints. Replays do not award more seeds. Each of six plants costs ten seeds; spending checks both balance and ownership. There are no purchases, advertising, paid boosts, energy gates or expiring plants.

Each co-op partnership also has a shared milestone garden. Completed co-op trails unlock plants after 1, 3, 5, 8, 12 and 20 walks together. Bot partnerships work the same way. Human milestones derive from validated completed Game Center match history; each trail ID counts once per partner. Personal collections stay on-device, and retained completed human matches can recover shared milestones on a new device.

Nine local badges recognise the first trail, an efficient unassisted route, 10 and 50 rewarded trails, 7- and 30-day daily streaks, co-op, a versus win and a six-letter completion. Bot games count. The daily streak uses UTC completion days; finishing an old saved puzzle cannot backdate a streak.

## Visual direction

The concept image had foliage merging with stones, inconsistent perspective and ambiguous step counting. Production artwork uses original vector geometry: flat rolling hills, one consistent path, simple botanical marks and a restrained sun. The icon is drawn in AppKit, the landscape in SwiftUI Canvas, and functional icons use SF Symbols. No generated textures, synthetic faces or decorative pseudo-lettering ship in the app.

Serif display headings, rounded letter tiles, a cream/sage/forest palette, native navigation and adaptive text colour establish a consistent style. Changed letters are underlined as well as tinted. Words have VoiceOver labels that spell their letters. Scenes are static. Larger type uses scrolling; a simulator test captures dark mode at the largest accessibility text size.

## Data and limits

The game has no standalone backend, website dependency, separate password database, analytics SDK or chat. Local JSON is written atomically with iOS file protection. Corrupt saves are preserved rather than overwritten. Local progress does not automatically sync between devices in version 1. Apple handles Game Center identities, friendships, matches and notifications. Apple account settings control friends and blocking.

Future changes to the dictionary need multiplayer compatibility/version handling so active matches retain their rules. Before a broad beta, human invitations, co-op, versus, forfeits and notifications must be exercised on two real devices. Automated simulator tests cannot prove delivery of Apple push notifications or multiplayer service behavior between two accounts.
