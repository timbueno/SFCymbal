#!/bin/bash
# Build and notarize a local release. Credentials are read from the Keychain.
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: scripts/release.sh [--check]

Required environment:
  SIGNING_IDENTITY  Full Developer ID Application certificate name
  NOTARY_PROFILE   Profile created with xcrun notarytool store-credentials

Optional environment:
  RELEASE_ROOT     Output parent directory (default: build/releases)

Versions, bundle identifier, and signing team come from the Release settings.
--check validates prerequisites without building or submitting an app.
Each release uses a new output directory; existing artifacts are never replaced.
EOF
}
fail() { printf 'Error: %s\n' "$*" >&2; exit 1; }
check_only=false
case "${1:-}" in
  --help|-h) usage; exit 0 ;;
  --check) check_only=true ;;
  '') ;;
  *) usage >&2; exit 2 ;;
esac
[[ $# -le 1 ]] || fail 'Too many arguments.'

cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[[ $(uname -s) == Darwin ]] || fail 'macOS and full Xcode are required.'
[[ -n ${SIGNING_IDENTITY:-} ]] || fail 'Set SIGNING_IDENTITY to a Developer ID Application certificate name.'
[[ $SIGNING_IDENTITY == 'Developer ID Application: '* ]] || fail 'A Developer ID Application certificate is required.'
[[ -n ${NOTARY_PROFILE:-} ]] || fail 'Set NOTARY_PROFILE to a notarytool Keychain profile.'
xcrun --find notarytool >/dev/null
xcrun --find stapler >/dev/null
security find-identity -v -p codesigning | grep -F -- "\"$SIGNING_IDENTITY\"" >/dev/null \
  || fail 'The signing identity and private key are not available in the Keychain.'

# A release must correspond to committed source, including Package.resolved.
[[ -z $(git status --porcelain --untracked-files=normal) ]] \
  || fail 'Commit or stash working-tree changes before releasing.'
commit=$(git rev-parse HEAD)
project='SF Cymbal.xcodeproj/project.pbxproj'
# Read the app target Release configuration, not the test target or Debug settings.
settings=':objects:000000000000000112000000:buildSettings'
read_setting() { /usr/libexec/PlistBuddy -c "Print $settings:$1" "$project"; }
version=$(read_setting MARKETING_VERSION)
build=$(read_setting CURRENT_PROJECT_VERSION)
team=$(read_setting DEVELOPMENT_TEAM)
bundle_id=$(read_setting PRODUCT_BUNDLE_IDENTIFIER)
[[ $version =~ ^[0-9]{4}\.[1-9][0-9]*$ ]] || fail 'MARKETING_VERSION must be year.release, such as 2026.1.'
[[ $build =~ ^[1-9][0-9]*$ ]] || fail 'CURRENT_PROJECT_VERSION must be a positive integer.'
[[ $bundle_id != *devplaceholder* && $bundle_id != *'$('* ]] \
  || fail 'Set a permanent PRODUCT_BUNDLE_IDENTIFIER in the project before releasing.'
[[ $SIGNING_IDENTITY == *"($team)" ]] || fail 'The signing certificate must match DEVELOPMENT_TEAM.'
# Check authentication early, without submitting software.
xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" --output-format json >/dev/null
printf 'Ready: SF Cymbal %s (%s), %s, commit %s\n' "$version" "$build" "$bundle_id" "$commit"
if $check_only; then exit 0; fi

root=${RELEASE_ROOT:-"$PWD/build/releases"}
mkdir -p "$root"
root=$(cd "$root" && pwd)
output=$(mktemp -d "$root/SF-Cymbal-$version-$build.XXXXXX")
trap 'printf "Release failed. Diagnostics retained in: %s\n" "$output" >&2' ERR
archive="$output/SF Cymbal.xcarchive"
app="$output/staging/SF Cymbal.app"
printf 'Release directory: %s\n' "$output"

xcodebuild -project 'SF Cymbal.xcodeproj' -scheme 'SF Cymbal' \
  -configuration Release -destination 'generic/platform=macOS' \
  -archivePath "$archive" -derivedDataPath "$output/DerivedData" \
  -onlyUsePackageVersionsFromResolvedFile -skipMacroValidation \
  CODE_SIGN_STYLE=Manual "CODE_SIGN_IDENTITY=$SIGNING_IDENTITY" \
  "DEVELOPMENT_TEAM=$team" ENABLE_HARDENED_RUNTIME=YES \
  'OTHER_CODE_SIGN_FLAGS=--timestamp' \
  'ARCHS=arm64 x86_64' ONLY_ACTIVE_ARCH=NO archive 2>&1 | tee "$output/archive.log"

mkdir "$output/staging"
ditto "$archive/Products/Applications/SF Cymbal.app" "$app"
plist="$app/Contents/Info.plist"
[[ $(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$plist") == "$version" ]]
[[ $(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$plist") == "$build" ]]
[[ $(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$plist") == "$bundle_id" ]]
# Check each slice separately; some Xcode lipo versions reject multiple arches.
xcrun lipo "$app/Contents/MacOS/SF Cymbal" -verify_arch arm64
xcrun lipo "$app/Contents/MacOS/SF Cymbal" -verify_arch x86_64
codesign --verify --deep --strict --verbose=2 "$app"
codesign -d --verbose=4 "$app" 2> "$output/signature.txt"
grep -F -- "Authority=$SIGNING_IDENTITY" "$output/signature.txt" >/dev/null
grep -F -- '(runtime)' "$output/signature.txt" >/dev/null
grep -F -- 'Timestamp=' "$output/signature.txt" >/dev/null
codesign -d --entitlements - --xml "$app" > "$output/entitlements.plist"
[[ $(/usr/libexec/PlistBuddy -c 'Print :com.apple.security.app-sandbox' "$output/entitlements.plist") == true ]] \
  || fail 'The release must retain App Sandbox.'
[[ $(/usr/libexec/PlistBuddy -c 'Print :com.apple.security.files.user-selected.read-write' "$output/entitlements.plist") == true ]] \
  || fail 'The release must retain user-selected file access.'
debug_access=$(/usr/libexec/PlistBuddy -c 'Print :com.apple.security.get-task-allow' "$output/entitlements.plist" 2>/dev/null || true)
[[ $debug_access != true ]] || fail 'A release must not grant debugger access.'

ditto -c -k --keepParent "$app" "$output/notarization.zip"
notary_exit=0
xcrun notarytool submit "$output/notarization.zip" \
  --keychain-profile "$NOTARY_PROFILE" --wait --output-format plist \
  > "$output/notarization.plist" || notary_exit=$?
submission=$(/usr/libexec/PlistBuddy -c 'Print :id' "$output/notarization.plist" 2>/dev/null || true)
status=$(/usr/libexec/PlistBuddy -c 'Print :status' "$output/notarization.plist" 2>/dev/null || true)
if [[ -n $submission ]]; then
  xcrun notarytool log "$submission" --keychain-profile "$NOTARY_PROFILE" \
    "$output/notarization-log.json" || true
fi
[[ $notary_exit == 0 && $status == Accepted ]] \
  || fail "Notarization did not succeed (status: ${status:-unknown}). See $output."
xcrun stapler staple "$app"
xcrun stapler validate "$app"
codesign --verify --deep --strict --verbose=2 "$app"
spctl --assess --type execute --verbose=2 "$app"

# Repackage AFTER stapling so the download contains the ticket.
artifact="SF-Cymbal-$version.zip"
ditto -c -k --keepParent "$app" "$output/$artifact"
(cd "$output" && shasum -a 256 "$artifact" > "$artifact.sha256")
{
  printf 'Version: %s\nBuild: %s\nBundle: %s\nCommit: %s\nNotarization: %s\n' \
    "$version" "$build" "$bundle_id" "$commit" "$submission"
  xcodebuild -version
} > "$output/release.txt"
printf '\nRelease ready: %s\nChecksum: %s\n' "$output/$artifact" "$output/$artifact.sha256"
