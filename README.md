# Word Trails

Native iPhone word trails for iOS 17 and later. Daily solo play works offline, with optional real-friend co-op through Apple Game Center. No versus mode or bots. The website ways2earn.com is neither accessed nor changed.

Current internal TestFlight beta: **1.1.0 (5)**, Apple processing `VALID`, assigned to Word Trails Internal with status **Testing**. Release source: `testflight-1.1.0-5` (`edcee235ed5194a98b206f0b6627c194c999e9b8`). All 15 engine tests and four iPhone simulator UI tests passed.

<img src="docs/screenshots/08-Statistics.png" width="260" alt="Statistics per difficulty"> <img src="docs/screenshots/06-Complete.png" width="260" alt="An optimal route finishing one under par">

## Update 1.1

- 37,819 accepted English word forms across the supported 3–6-letter lengths, including inflections and regional spellings. Includes SNARES. A comprehensive spellchecker dictionary, not a claim to contain every English word or proper name.
- 40,000 different trails: 10,000 at each difficulty, over 27 years per difficulty before a pair repeats.
- Every new trail has a familiar-word shortest solution. Breadth-first search across the full dictionary independently confirms no shorter obscure-word route. Minimum steps are at least 4/5/6/7 for 3/4/5/6 letters.
- Par is minimum +1 for 3/4 letters, minimum +2 for 5/6. A difficulty-based target rather than a measured population average.
- Statistics per difficulty and overall: attempts, completions, completion rate, below/on/above par, shortest routes, average steps, average and best result against par. Replays count as new attempts; resuming the same run does not. Historical completions are imported; previously abandoned attempts cannot be reconstructed.
- Daily reminders are opt-in, at a user-selected local time. Repeating iOS local notifications work offline and replace the old scheduled time. System notification settings still apply.
- Existing seeds, plants, streaks and completed routes persist. Historical pars stay unchanged. Unfinished old solo/bot trails migrate to solo and use the expanded dictionary and updated par.

## Play and privacy

Change exactly one letter per step; no repeated words. Solo offers hints and undo. Optional co-op alternates one word per turn with a real Game Center partner, without hints or undo. Solo needs no account or internet. Invitations, friends, turn data and turn alerts use Apple Game Center; there is no independent account database or website backend. The co-op pool uses data version 2, while existing version-1 co-op matches retain their original dictionary and rules. Earlier versus matches are hidden.

Rewards include seeds, six collectible plants, eight badges, daily streaks and shareable results. Seeds are awarded only once per puzzle and mode. Completed friend co-op trails grow shared gardens. Personal progress remains on the device, without cross-device synchronization.

Original vector landscapes, SF Symbols, system typography, Dynamic Type, VoiceOver and dark mode. No generated raster art, ads, analytics SDK, chat, purchases or contact uploads.

## Content provenance and verification

ESDB/SCOWL official release `rel-2026.02.25`, pinned mirror revision `71d7dd07676edb60ade43552e10b41314b7e9287`. Accepted list uses size 85; familiar routes use the size-35 list screened with wordfreq 3.1.1 and editorial inclusions/exclusions. The latter is a practical familiarity proxy, not a guarantee that everyone knows each word. Only 3–6-letter A–Z forms are accepted. Prior accepted words remain available for save compatibility.

Source, extraction settings and hashes are bundled in `dictionary-source.json`; complete notices in `Dictionary-Licence.txt` and `Familiar-Licence.txt`. Reproduce extraction with `scripts/import-dictionary.py` using the official pinned database/tools, then run `python scripts/screen-familiar.py` (wordfreq 3.1.1 required) and `node scripts/generate-trails.mjs`. Catalog generation never silently relaxes the difficulty or familiar-route requirements.

On a Mac with Xcode and XcodeGen:

```sh
swift test -c release --parallel
swift Support/make-icon.swift App/Assets.xcassets/AppIcon.appiconset
xcodegen generate
xcodebuild test -project WordTrails.xcodeproj -scheme WordTrails -destination 'platform=iOS Simulator,name=iPhone 17' CODE_SIGNING_ALLOWED=NO
```

Engine tests verify all 40,000 minima independently, legal familiar witnesses, dictionary regressions, statistics, migration, rewards, co-op versioning and reminder times. Simulator UI tests cover solo completion, under-par scoring, statistics, reminder settings, onboarding, dark mode and large text. Two-device Game Center turns and real-device notification delivery require beta testing.

The validation workflow exports native simulator screenshot attachments. The isolated signing workflow archives the exact source revision and checks the bundle/version/build before TestFlight upload. See `docs/RELEASE.md` for release setup and earlier shipping history.
