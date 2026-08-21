# Petites Dents

Petites Dents is a private keepsake timeline for baby and permanent teeth on
iOS and Android. Families can record dates and observations, add photos and
prepare a portable PDF without creating an online profile.

- Timeline for 20 primary teeth and the permanent-tooth transition
- Dates, notes, photos and chronological history
- Local keepsake PDF preview and export
- One-time Souvenirs unlock; no subscription
- No advertising or third-party tracking

The app preserves family memories; it does not provide dental guidance.

## Technology and development

Android uses Kotlin, Jetpack Compose and Room at the repository root. The iOS
app under `ios/` uses Swift 6 and SwiftUI; `ios/project.yml` generates Xcode.

```sh
./gradlew test
./gradlew assembleDebug
cd ios
bundle install
xcodegen generate
xcodebuild -scheme PetitesDents -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

The platforms keep one aligned public version. `marketing/` generates `docs/`;
iOS release automation is in `ios/fastlane/`.

[Product site](https://bnjdpn.github.io/petites-dents/) · [Privacy](https://bnjdpn.github.io/petites-dents/privacy.html)
