# Petites Dents

Repo public dual-plateforme : Android (Kotlin/Compose/Room, JDK 17) à la
racine, iOS (SwiftUI/SwiftData/StoreKit 2) dans `ios/`. Journal privé des
dents de lait : les 20 dents en chronologie calme, un profil par enfant —
sans compte, pub, analytics ni serveur.

## Commandes

- Android : `./gradlew test` puis `./gradlew assembleDebug` (GRADLE_USER_HOME
  isolé, rapport JUnit non vide exigé).
- iOS : suivre `ios/AGENTS.md`.
- Site : éditer `marketing/`, régénérer `ruby scripts/marketing_site.rb`,
  valider `ruby scripts/marketing_site.rb --check` (échoue si `docs/` obsolète).
- Gate final de release : `ruby scripts/release_alignment_guard.rb --final`.

## Architecture

- `app/` — Android ; `ios/` — app iOS autonome (XcodeGen + Fastlane).
- `scripts/` — gardes dual-canal (release_alignment_guard,
  prepare_android_release) + génération site.
- `marketing/` — sources du site ; `docs/` — sortie GitHub Pages générée, ne
  jamais l'éditer à la main. `site/DIRECTION.md` — direction visuelle propre à
  l'app, pas de template portefeuille.
- `.github/workflows/pages.yml` — publie uniquement le site statique.

## Contrat de release dual-canal (non négociable)

- Android `versionName`, iOS `MARKETING_VERSION` et
  `ios/fastlane/release_config.json.version` = une seule version marketing ;
  exécuter le garde parent avant tout build de release.
- Fin de release : relire ASC puis vérifier la GitHub Release publique
  `v<version ASC>` (non draft/non prerelease) avec APK signé par le
  certificat historique, checksum SHA-256 et provenance. Le gate `--final`
  exige les JSON ASC/GitHub et les trois artefacts ; tout écart bloque.
- Ne jamais remplacer la clé de signature Android. Avant tag/POST GitHub :
  `gh api user --jq .login` doit réussir ; cibler le `source_commit` de la
  provenance, refuser retry ambigu ou écrasement d'une release existante.

## Limites

- Android et iOS partagent le même worktree : mutations sérialisées, outputs
  jamais mélangés.
- Artefacts iOS durables sous `ios/Builds/AppStore/PetitesDents/<run_id>/`.
