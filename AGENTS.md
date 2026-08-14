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
  log privé ou donnée utilisateur n'est ajouté. La monétisation suit le plan
  app-spécifique approuvé et `ios/fastlane/release_config.json`; garder produit,
  metadata, tests et ASC alignés lors de toute évolution.
- Android `versionName`, iOS `MARKETING_VERSION` et
  `ios/fastlane/release_config.json.version` sont une seule version marketing;
  exécuter le garde parent avant tout build de release.
- Aligner chaque release ASC avec une GitHub Release publique `v<version ASC>`,
  non draft/non prerelease, contenant l'APK signé par le certificat historique,
  son checksum SHA-256 et sa provenance. Le gate final exige les JSON ASC et
  GitHub ainsi que les trois artefacts; toute absence ou divergence bloque la
  release. Ne jamais remplacer silencieusement la clé Android.
- Avant tout tag ou POST GitHub, `gh api user --jq .login` doit réussir en GET;
  cibler le `source_commit` de la provenance et refuser tout retry ambigu ou
  écrasement d'une release existante.


## Site marketing

- Le site GitHub Pages est une surface produit app-locale : sa direction est
  documentée dans `site/DIRECTION.md` et ne doit pas être remplacée par un
  template visuel commun au portefeuille.
- Toute évolution publique de fonctionnalité, version, localisation, support,
  confidentialité ou métadonnée doit mettre à jour les sources `marketing/`,
  régénérer la sortie publique avec `ruby scripts/marketing_site.rb`, puis
  réussir `ruby scripts/marketing_site.rb --check` avant release.
- Le workflow `.github/workflows/pages.yml` ne publie que l’artefact statique
  isolé. Il ne construit, ne teste, ne signe et ne livre jamais l’app native.
