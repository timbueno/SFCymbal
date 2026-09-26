# Releasing SF Cymbals

Run `scripts/release.sh` on macOS with the full Xcode version documented in the README selected by `xcode-select` (or `DEVELOPER_DIR`). The script creates a universal arm64/x86_64 Release archive, signs with Developer ID and hardened runtime, exports to re-sign Sparkle’s nested helpers, submits to Apple, staples the accepted ticket, checks Gatekeeper, and creates a ZIP, SHA-256 checksum, and signed-update appcast. It follows [Apple’s notarization workflow](https://developer.apple.com/documentation/security/customizing-the-notarization-workflow).

## One-time setup

1. In Xcode → Settings → Accounts → Manage Certificates, create/install a **Developer ID Application** certificate for the project's development team, including its private key. An Apple Development certificate cannot sign a public release. Run `security find-identity -v -p codesigning` to find the full certificate name.
2. The app uses `io.deadpan.SFCymbal` as its permanent `PRODUCT_BUNDLE_IDENTIFIER` in both Debug and Release. Keep this identifier stable for future updates.
3. Store notarization credentials interactively in the Keychain:

   ```sh
   xcrun notarytool store-credentials "SF-Cymbal-notary"
   ```

   Follow the prompts for your Apple ID, team ID, and an app-specific password (or use the API-key options shown by `--help`). Do not put credentials in the repository or shell scripts.

4. Sparkle’s Ed25519 private key is stored in the login Keychain under account `io.deadpan.SFCymbal`. Only the public key is committed in `Configuration/Info.plist`. Preserve this Keychain item when migrating Macs; future updates need this key. On the original signing Mac, it has already been generated. After resolving packages, Sparkle’s tools are under `<DerivedData>/SourcePackages/artifacts/sparkle/Sparkle/bin/`. `generate_keys --account io.deadpan.SFCymbal -p` prints only the existing public key. On another signing Mac, securely transfer the existing private key using Sparkle’s documented export/import workflow rather than generating a replacement.

## Build a release

Update `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` in both app configurations. Public versions start at `2026.1`; build numbers must increase across every public release, including across years. Compare against the last published release; the script validates the format but does not query published release history.

Run the test suite from the README and review the pinned package revisions, then commit all release source changes. The script requires a clean working tree so `release.txt` identifies the exact source used. It permits the pinned dependencies' build macros with `-skipMacroValidation`, as the existing test command does.

```sh
export SIGNING_IDENTITY='Developer ID Application: Your Name (YOURTEAMID)'
export NOTARY_PROFILE='SF-Cymbal-notary'

scripts/release.sh --check
scripts/release.sh
```

`--check` checks signing identity, committed source, version settings, and Keychain authentication without building or uploading an app. The normal run uploads the signed app to Apple's notarization service. No Git tag or GitHub release is created.

Each run gets a unique directory under `build/releases/` (override with `RELEASE_ROOT`). Keep the archive and dSYMs for debugging. The directory also contains the build log, signing details, notarization result/log, and source/toolchain metadata. If notarization fails, consult those logs; correct the issue and rerun. No final download ZIP is produced unless notarization, stapling, and Gatekeeper checks all pass.

The publishable files are `SF-Cymbals-2026.1.zip`, its `.sha256` file, and `appcast.xml`. Treat a run as successful only when it prints `Release ready` and writes `release.txt`; appcast generation or signature validation can fail after the ZIP is created. The separate `notarization.zip` is the pre-stapling upload and **must not be published**. Test the final ZIP on a clean Mac before publishing, including import/export and document saving. Tag the recorded commit as `v2026.1` and attach the final ZIP, checksum, and appcast to that GitHub release once ready. Mark it as the latest stable release. The app uses `https://github.com/timbueno/SFCymbal/releases/latest/download/appcast.xml`; appcast enclosures point to the immutable `releases/download/v2026.1/` asset URL. Upload all three assets before publishing the release. Do not replace the ZIP after generating its appcast signature.

The script reads Sparkle’s signing key from Keychain, checks it matches the public key in the exported app, generates `appcast.xml` from the stapled ZIP, and verifies its EdDSA signature. Each feed contains the current full update; delta updates are disabled. If a future release drops support for an older macOS version, preserve compatible entries in the appcast before publishing instead of replacing it with a single new entry.

The app remains sandboxed, using Sparkle’s installer and downloader XPC services and its two documented Mach lookup exceptions. The main app does not gain general network access. Debug builds disable the updater; use a Release build to check the menu and update flow. Sparkle manages the automatic-check permission prompt and stores the user’s choice.

Before the first public release, test an older Sparkle-enabled build upgrading to a higher build number using a test feed, including relaunch and document preservation. The original build without Sparkle cannot update itself. A public update check will fail until the first GitHub release and its appcast are published. The script never publishes or pushes anything itself.

## Release privacy

The release script exports the committed source into a temporary `/private/tmp/SFCymbal-release.*` workspace and builds dependencies there as well. This avoids personal paths even in Swift source-location literals that compiler remapping does not cover. The temporary workspace is removed when the script exits. Before notarization, `scripts/check_release_privacy.py` scans every regular file in the exported app and rejects `/Users/<name>/` or `/home/<name>/` paths. This includes embedded frameworks and resources; a dependency that introduces such paths will stop the release for review. Archives, dSYMs, and diagnostic logs remain local and can still contain personal paths. Publish only the ZIP, checksum, and appcast.

Private signing exports and generated `SF-Cymbals-<version>-<build>.*` output directories are ignored, including when `RELEASE_ROOT` is changed. Intentional public PEM files can use the `.pub.pem` suffix. Ignore rules are preventive and do not replace reviewing staged files for secrets.

## Validate script changes

Run `bash -n scripts/release.sh` and `python3 -m unittest discover -s scripts/tests -v` on macOS. The tests use temporary projects and mock signing/build services to check successful packaging and failure gates without uploading software. A real Developer ID release is still needed to verify signing and notarization end to end.

## Validation record — 2026-09-26

Build 3 was built from commit `5053e25` in a neutral temporary workspace. The exported app and every regular file in the final extracted ZIP passed the user-home path scan. Apple notarization, stapling, Gatekeeper assessment, ZIP checksum, and Sparkle update-signature verification passed.

A separate installed copy of notarized build 2 successfully checked a localhost appcast, downloaded the signed build 3 ZIP, installed it, and relaunched. The About window and installed bundle both confirmed build 3. The temporary feed override was restored and the localhost server stopped. Nothing was published.

Document-preservation testing is **not complete**. Before updating, the older build stalled after selecting “Try an example” and immediately invoking Save; a process sample showed the main thread waiting in AppKit document serialization. The test process was stopped. A separately generated blank project fixture was not openable through the test app's Open panel (Open remained disabled). That fixture remained byte-for-byte unchanged after the update, but this does not verify open-document restoration or unsaved edits. Investigate and repeat document save/open/restoration QA before public release. Local diagnostic evidence remains under the ignored `build/update-test/` directory.

The subsequent manual test of the public 2026.1 release was completed by the maintainer, who confirmed that the update and project-preservation steps worked as expected.

## SF Cymbals relaunch

The app is now **SF Cymbals** (build 4). New downloads contain `SF Cymbals.app`. The bundle identifier `io.deadpan.SFCymbal`, `.sfcymbal` document extension and type identifier, Sparkle public key, Keychain account/profile, and GitHub feed URL are unchanged. Internal Xcode project, scheme, source directory, and Swift module names remain stable.

Sparkle preserves the existing installation filename during an update. Existing users get the new app name in its menus and About window, but their on-disk filename can remain `SF Cymbal.app`. They can quit and rename it to `SF Cymbals.app` in Finder. Do not ship custom self-moving code or rebuild Sparkle solely to force the filename change. Before adoption, the maintainer explicitly chose to replace the initial 2026.1 release with the renamed app, build 4. Subsequent public updates should use new versions and increasing build numbers.
