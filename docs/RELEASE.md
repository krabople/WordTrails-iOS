# Word Trails release

Bundle: `com.krabople.wordtrails`. Team: `6YYA8L76Y8`. Website hosting, DNS, website databases and cPanel are not involved.

The public `krabople/WordTrails-iOS` repository runs validation and signing on standard GitHub-hosted macOS runners. GitHub provides free standard runner minutes for public repositories; normal artifact-storage limits apply. See https://docs.github.com/en/actions/concepts/billing-and-usage.

## Signing

Five encrypted GitHub Actions repository secrets are configured:

- BUILD_CERTIFICATE_BASE64
- P12_PASSWORD
- APPSTORE_ISSUER_ID
- APPSTORE_KEY_ID
- APPSTORE_PRIVATE_KEY

No signing key or password is committed. The manual release workflow is the only current workflow referencing these secrets. Fork pull-request validation receives no signing secrets. Only maintainers should be allowed to change or run release workflows.

The workflow accepts an immutable tested 40-character source SHA. It imports the distribution certificate into the runner keychain, restricts Apple setup to the exact Word Trails bundle, reuses the imported certificate and creates only this app's provisioning profile. It does not revoke certificates or change other apps' profiles. Explicit packaged version/build checks run before upload.

Run wordtrails-testflight.yml in WordTrails-iOS with source_ref set to the tested SHA and setup_only=false. The version comes from project.yml and the workflow marketing version; the build number follows this workflow's run counter. Version 1.2.0 starts at build 1 in the new repository workflow.

Success requires Apple's exact version/build to reach VALID. The verification script waits for that state. Internal group assignment is a separate final step in App Store Connect. External testing requires beta review and an explicitly chosen group; no mass invitations are sent automatically.

## Earlier shared signing setup

The original source repository was private and used a read-only deploy key in Lifetwine's isolated Word Trails workflow. Public source checkout no longer needs that key. The owner approved transferring five signing secrets to Word Trails using a temporary one-job runner and GitHub's destination encryption key. Only sealed values were transferred as artifacts. The runner unregistered, its files and transfer artifact were removed, and the temporary transfer job was removed from the shared workflow.

Lifetwine's app files, other workflows, secrets and repository visibility were not changed. Future Word Trails builds are independent of that repository.

## Device testing

Engine tests verify rules, all catalog minima, familiar witnesses, hint fallback behavior, daily consistency, achievements, migration, rewards and co-op versioning. Simulator UI checks cover play, badge notices, rendered sharing, settings, dark mode and large text. Real-device Game Center invitations/turns and notification delivery still need beta testing on physical devices.
