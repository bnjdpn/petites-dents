# Petites Dents — iOS

Surface iOS du repo public `petites-dents`. Scheme `PetitesDents`, bundle
`com.bnjdpn.petitesdents`. `project.yml` est la source XcodeGen de
`PetitesDents.xcodeproj` : régénérer, ne jamais éditer le .xcodeproj.

## Commandes

- `xcodegen generate`
- Build non signé : `xcodebuild -scheme PetitesDents -destination 'generic/platform=iOS Simulator' -derivedDataPath '/private/tmp/apps-factory/PetitesDents/cache/DerivedData' CODE_SIGNING_ALLOWED=NO build`
- Tests (UDID possédé obligatoire) : `xcodebuild test -scheme PetitesDents -destination 'platform=iOS Simulator,id=<udid>' -derivedDataPath '/private/tmp/apps-factory/PetitesDents/cache/DerivedData' -resultBundlePath '/private/tmp/apps-factory/PetitesDents/<execution_id>/xcresult/<operation_id>.xcresult' -parallel-testing-enabled NO`
- Captures : `env APPS_FACTORY_DEVICE_UDIDS_JSON='{...}' RELEASE_RUN_ID=<execution_id> /opt/homebrew/bin/ruby -S bundle exec fastlane screenshots`
- Contrat : `/opt/homebrew/bin/ruby -S bundle exec fastlane release_contract` ;
  readback : `/opt/homebrew/bin/ruby -S bundle exec fastlane asc_status`

Lanes disponibles : setup_asc, release_contract, asc_status, metadata,
screenshots, app_previews, media_contract, upload_screenshots,
upload_previews, build_release, upload_release, submit_review, release_quick,
pricing, iap_status, iap_sync. (Pas de lane `test` : tests via xcodebuild.)

## Architecture

- `PetitesDents/` — code ; tests dans `PetitesDentsTests/` et
  `PetitesDentsUITests/`. Le scheme embarque
  `PetitesDents/Resources/PetitesDents.storekit`.
- `fastlane/release_config.json` — source de vérité release : version,
  pricing, IAP (tips), `app_preview_policy`, matrice média.
- `fastlane/simulator_requirements.json` + `media_expectations.json` —
  contrat captures ; générateur `scripts/app_store/generate_screenshots.rb`.
- `ios/scripts/release_contract.rb` — contrat de release app-local.

## Captures d'écran

- Matrice figée : en-US/en-GB/fr-FR × iPhone 17 Pro Max + iPad Pro 13" M5 ×
  4 scènes (Mouth, ToothDetail, History, ExportAndSupport), runtime iOS 26.2,
  dimensions exactes exigées par `media_expectations.json`.

## Limites

- Release depuis `main` via Fastlane/ASC API uniquement ; TestFlight n'est
  pas une cible.
- `release_contract` doit réussir le garde parent Android/iOS ; après
  soumission ASC, le gate final exige la GitHub Release du même tag (APK,
  checksum, provenance) avant toute déclaration de fin.
- `app_preview_policy` relue à chaque release ; ne jamais déduire la décision
  vidéo d'un ancien dossier.
- Surface clone-autonome, aucune dépendance au portefeuille parent.
- Preuves durables sous `Builds/AppStore/PetitesDents/<run_id>/`.
