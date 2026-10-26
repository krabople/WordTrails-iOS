# Release isolation

Bundle: `com.krabople.wordtrails`. Team: `6YYA8L76Y8`. No website, hosting, DNS, existing website database, or cPanel settings are involved.

The manual workflow `.github/workflows/wordtrails-testflight.yml` accepts an immutable source SHA and runs on a Mac. It can run in this repository once its signing secrets exist, or as an isolated additional workflow in the owner's existing signing repository, with explicit owner authorization. No other app's source or workflow is changed.

Expected secrets: `BUILD_CERTIFICATE_BASE64`, `P12_PASSWORD`, `APPSTORE_ISSUER_ID`, `APPSTORE_KEY_ID`, `APPSTORE_PRIVATE_KEY`. For a shared signing runner, `WORDTRAILS_SOURCE_DEPLOY_KEY` is a new read-only deploy key restricted to the private Word Trails source repository. Existing Apple private keys remain within the existing signing repository's Actions environment; they are not downloaded or printed.

Run `setup_only=true` first. The script registers only the exact Word Trails bundle, enables its Game Center capability, selects the existing imported distribution certificate by SHA-1 and team, and creates a dedicated profile. It does not revoke certificates or alter profiles for other apps. It fails on any other bundle ID.

Apple requires creating the new app record on the App Store Connect website. Use iOS, English UK, name `Word Trails` (or a unique available name), bundle `com.krabople.wordtrails`, SKU `wordtrails-ios-001`, full access. Enable Game Center for this app version. No leaderboards or Apple-hosted achievements are required; version 1 badges are local. Then run the workflow with `setup_only=false` at the validated SHA.

Success requires a processed `VALID` build in Apple, not merely a successful upload. Add the build to the owner's internal TestFlight group after processing. External testers require separate beta review and an explicitly chosen tester group; no mass invitations are sent automatically.

Test human co-op, versus, friend invitations, forfeits, turn notifications, interruption and restore on two real signed-in devices. Simulator UI checks and engine tests cannot establish Apple service behavior or device notification delivery.
