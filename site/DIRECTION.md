# Direction — Petites Dents

## Ressenti

Une fiche de souvenir que l’on classe et garde, avec la retenue d’une petite archive familiale plutôt qu’un univers de dentisterie.

## Langage visuel

Papier crème, bois patiné, ruban corail et typographie de registre. Aucun personnage-dent, sourire, étincelle ou illustration CSS/SVG.

## Traduction web

`en-GB`, `en-US` et `fr-FR` sont rendus depuis les métadonnées réelles de la version publique 1.0.7, avec badges officiels et URLs localisées.

## Layout

Le titre ressemble à une cote d’archive. Le hero est un objet-souvenir photographié ; les fonctions sont des annotations numérotées, puis un registre linéaire vers les autres apps Petites.

## Assets et provenance

- Source unique des visuels produit : les captures App Store réelles et localisées de la version publiée, récupérées à leur résolution native et suivies dans `marketing/shots/<locale>/`.
- Aucune illustration générée n'est publiée. Le dossier `marketing/art/` a été supprimé avec le raster éditorial qui s'y trouvait ; il ne représentait pas l'app.
- Dérivées servies : 440 et 880 px de large, en AVIF puis WebP, via `<picture>` + `srcset`/`sizes`. Les attributs `width`/`height` portent les dimensions réelles de la plus grande variante, donc aucun étirement ni réservation d'espace erronée.
- Couverture : 3 locale(s) × 3 capture(s), chacune mappée explicitement dans `marketing/site.json > local_assets`.
- Contrat de design : `hero_raster` = `assets/shots/en-US/01-880.webp` (880 × 1912), `hero_source` = `app-store-screenshot`. La page 404 et les métadonnées Open Graph pointent la même capture réelle.
- Carte sociale `marketing/web/social-card.jpg` : composition locale à partir de la vraie icône App Store, de la première capture et des couleurs déclarées par le thème. Aucun texte inventé.
- Icônes : `marketing/web/app-icon-*.png` et `marketing/web/related/*.png` sont dérivées des icônes App Store publiées, en 256 px minimum pour rester nettes en 2× et 3×.
- Aucun lien vers un CDN Apple : tout est auto-hébergé, donc rien ne casse quand une fiche App Store change.

Aucune fausse interface n'est publiée : la seule interface visible est une capture réelle de l'app.

## Différence et clichés évités

Pas de dent flottante, pas de gradient rose, pas de sourire publicitaire, pas de stérilité clinique, pas de cartes. La seule UI montrée est un screenshot réel.
