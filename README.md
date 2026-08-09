# Petites Dents

Petites Dents is a private baby-teething log for Android and iOS. It turns the
20 primary teeth into a simple interactive timeline without an account,
advertising, analytics, or a remote server.

## Features

- Anatomically ordered upper and lower arches for all 20 primary teeth.
- Three clear states: not started, teething, and erupted.
- Start and eruption dates, free notes, reset, and chronological history.
- A local PDF summary that can be shared with a paediatrician or kept with the
  child's health record.
- French, US English, and British English on iOS; French and English on Android.
- Optional iOS tips that unlock nothing. Every feature remains free.

Petites Dents is a personal log, not a medical device or a diagnostic tool.

## Privacy

Records remain on the device. The app has no account, tracking SDK, analytics,
advertising, or application server. Read the full
[privacy policy](https://bnjdpn.github.io/petites-dents/privacy.html) or use the
[support form](https://bnjdpn.github.io/petites-dents/#contact).

## Build

Android requires JDK 17:

```sh
./gradlew test
./gradlew assembleDebug
```

iOS requires Xcode 26 and XcodeGen:

```sh
cd ios
xcodegen generate
xcodebuild -scheme PetitesDents -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

The signed Android APK is published with each
[GitHub release](https://github.com/bnjdpn/petites-dents/releases).

## Release alignment

Android `versionName`, iOS `MARKETING_VERSION` and
`ios/fastlane/release_config.json.version` must be identical. Validate the
candidate before building it:

```sh
rtk proxy /opt/homebrew/opt/ruby/bin/ruby scripts/release_alignment_guard.rb --expected-tag vX.Y.Z
```

Prepare the signed APK, checksum and provenance under the isolated run scratch
with `scripts/prepare_android_release.rb`. The final
`release_alignment_guard.rb --final` gate requires ASC and GitHub readback JSON
plus all three assets, and rejects a missing side, wrong tag or APK manifest,
changed signer certificate, or checksum/provenance mismatch.

Before any tag or GitHub mutation, a read-only authenticated GET
(`gh api user --jq .login`) must succeed. Create the tag/release at the exact
`source_commit` recorded in provenance; never overwrite or automatically retry
an existing or ambiguous release.
