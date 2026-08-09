# Petites Dents

> Isolation : `/private/tmp/apps-factory/PetitesDents/<execution_id>/`. Une
> isolation complète du daemon CoreSimulator requiert une VM macOS éphémère ou un runner macOS éphémère.

Repo public dual : Android (Kotlin/Compose/Room, JDK 17) au root et iOS
(SwiftUI/SwiftData/StoreKit 2) dans `ios/`. Utiliser `rtk proxy` et sérialiser
toute mutation du worktree partagé.

- Android : `GRADLE_USER_HOME` isolé, `./gradlew test`, `./gradlew assembleDebug`
  et vérification d'un rapport JUnit non vide.
- iOS : suivre `ios/AGENTS.md`, garder Xcode/Fastlane/ASC dans `ios/` et les
  artefacts sous `ios/Builds/AppStore/PetitesDents/<run_id>/`.
- Vérifier avant push public qu'aucun secret, profil, keystore, credential,
  log privé ou donnée utilisateur n'est ajouté. Pas de paywall, tracking,
  backend, compte ou IAP non-tip sans plan explicite.
- Aligner chaque release ASC avec une GitHub Release `v<version ASC>` non draft,
  non-prerelease et contenant un APK; stopper et signaler toute divergence.
