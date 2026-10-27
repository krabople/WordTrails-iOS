# Word Trails 1.4 — universal app and store media

Version **1.4.0 (4)** supports iPhone and iPad on iOS/iPadOS 17+. Apple processed the upload as `VALID`; build `ff275faf-7d06-4783-9df2-994ab554354a` is Testing in the existing Word Trails Internal group, with its existing single tester.

## Verification and provenance

- Release source: `7526b90922b57dac74650828c6dfb3cb0cfd58ea`, tag `testflight-1.4.0-4`.
- Native app checks and screenshots: [validation 40424719235](https://github.com/krabople/WordTrails-iOS/actions/runs/40424719235), commit `2c221a4807448223698880242eecde7ff8462aa1`. All 23 engine tests and both simulator jobs passed. The release app sources, resources, tests and project settings are identical; the later commits only correct/refine the offline artwork renderer and add its workflow.
- Artwork: [composition 40426922536](https://github.com/krabople/WordTrails-iOS/actions/runs/40426922536), at the release revision.
- Signed app: [release 40426676368](https://github.com/krabople/WordTrails-iOS/actions/runs/40426676368). The IPA was independently opened and checked for device families `[1,2]`, version/build, bundle ID, iOS 17 minimum, iPhone portrait and all four iPad orientations.
- iPhone video uses the final validation take. The iPad video selects a fully settled take from [validation 40424321393](https://github.com/krabople/WordTrails-iOS/actions/runs/40424321393), commit `04128d4b0c30c06476ad42f946295e47679caa23`; the gameplay, sharing and garden views shown in that recording are unchanged in the release. Its iPad job also passed. The pack's manifest records these separately.

## Listing pack

Ten styled portrait screenshots for the 6.9-inch iPhone group (1320×2868), and ten for the 13-inch iPad group (2064×2752). They are opaque 8-bit RGB PNGs. The unstyled captures are retained. All twenty frames were visually reviewed; headings and artwork are code-drawn around actual UI captures.

Two 28-second H.264 High Profile Level 4.0 previews, 30 fps, at 886×1920 and 1200×1600. Each includes a British English synthetic narration, visible captions, stereo AAC at 48kHz, and a closing hold on the recorded garden frame. Encoder targets are 10Mbps video and 256kbps AAC; average rates vary with static interface content and speech pauses. Original uninterrupted recordings, WAV narration, script, timings, captions, checksums and an HTML review gallery are included.

The sample history is isolated Debug-only simulator data made with real catalogue puzzles, legal moves and normal rewards. It cannot appear in the Release app. No personal user data, fictional friends or bot accounts are depicted. The Cori voice creator identifies the voice and its LibriVox source recordings as public domain: https://brycebeattie.com/files/tts/.

Run the `Compose App Store artwork` workflow with a validation run ID to reproduce the styled screenshots. `Support/make-store-assets.swift` draws them using AppKit. `Support/make-store-previews.py` can rebuild the videos from a media-pack folder with FFmpeg installed; it expects the supplied narration and timing files.

Apple references: https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/ and https://developer.apple.com/help/app-store-connect/reference/app-information/app-preview-specifications/.

## Beta scope

Portrait, landscape input, live rotation, result sharing, badges, saved-trail access, dark mode and large text were exercised in Apple simulators. Two-account Game Center co-op and real background notification delivery still need physical-device beta testing. Solo progress remains local to each device; there is no iPhone/iPad progress synchronization. Dictionary content, daily schedules, par rules and the saved-progress format are unchanged. Website hosting and databases were not accessed.

Listing files were produced for review; no App Store listing or public release was submitted.
