# Petites Dents iOS

> Isolation : `/private/tmp/apps-factory/PetitesDents/<execution_id>/`. Une
> isolation complète du daemon CoreSimulator requiert une VM macOS éphémère ou un runner macOS éphémère.
> Avant soumission, relire `fastlane/release_config.json.app_preview_policy`.

Surface iOS du repo public parent. Respecter ses règles de sécurité et la
sérialisation du worktree partagé; toute commande passe par `rtk proxy`.

- Utiliser `PetitesDents.xcodeproj` et XcodeGen lorsque `project.yml` change.
  Isoler UDID, DerivedData, xcresult et médias du run courant.
- Lancer tests et `bundle exec fastlane release_contract`; respecter la décision
  app-preview, les locales et le générateur déclarés dans `release_config.json`.
- ASC via Fastlane/API app-locale exclusivement, puis readback de version,
  build, prix gratuit, tips, médias et soumission avant commit/push du repo parent.
- Conserver les preuves app-locales et ne committer aucun secret, profil,
  certificat, keystore ou credential.
