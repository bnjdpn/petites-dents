# Petites Dents iOS

This directory is the autonomous iOS release surface for Petites Dents. Use
XcodeGen, SwiftUI, SwiftData, StoreKit 2, app-local Fastlane, and only the ASC
helpers in `scripts/app_store/`.

Every execution owns logs, xcresult and scratch under
`/private/tmp/apps-factory/PetitesDents/<execution_id>/`; the app reuses caches
under `/private/tmp/apps-factory/PetitesDents/cache/`. Builds may use a generic
destination, but tests, launches, captures, and media must use an exact UDID
leased from the fixed pool in the default device set. Never
target `booted`, select a simulator by name, or perform global cleanup. Full
CoreSimulator daemon separation requires an ephemeral macOS VM or runner.

Commit and push launch no tests. Release only from `main`; validate the exact
candidate once before archive, then commit after successful ASC readback.
Before submission, reread
`fastlane/release_config.json.app_preview_policy`; it must retain an
app-specific decision with `review_each_release=true`. Capture and validate
the full locale × device × scene matrix before the first ASC mutation.

The app remains free. Only the three optional consumable tips are allowed, and
they unlock nothing. App Store Connect credentials and private review-contact
values come from ignored files or environment variables and are never
committed.
