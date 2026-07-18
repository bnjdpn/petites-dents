# Petites Dents

This repository owns the Android app at the root and the independent iOS
surface under `ios/`. Keep all product code, release automation, metadata,
media, support pages, and ASC helpers app-local.

Run commands through `rtk`; use `rtk proxy` for unfiltered Git, Ruby,
Fastlane, Xcode, and search output. Android uses JDK 17, Kotlin, Compose, and
Room. iOS uses SwiftUI, SwiftData, StoreKit 2, XcodeGen, and Fastlane.

Mutable execution state belongs under
`/private/tmp/apps-factory/PetitesDents/<execution_id>/`. Simulator tests and
media must target an exact run-owned ephemeral UDID in the default device set.
Never target `booted`, a simulator name, or perform global simulator cleanup.
Complete CoreSimulator daemon isolation requires an ephemeral macOS VM or
runner; a local UDID lease isolates ownership, not the shared daemon.

Releases come from `main`. App Store mutations use only app-local Fastlane or
the scripts in `ios/scripts/app_store/`. The app is free; only the optional
`tip.cafe`, `tip.merci`, and `tip.soutien` consumables are permitted.
Credentials, signing material, generated archives, APKs, and `Builds/` are
never committed.

Before every iOS submission, reread
`ios/fastlane/release_config.json.app_preview_policy`. Its
`review_each_release` decision and app-specific reason are part of the release
contract.
