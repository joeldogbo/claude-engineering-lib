# Workflow : Nouvelle interface avec direction artistique

Pour une page ou une interface créée de zéro ou refondue (site vitrine, landing page, page d'accueil, premier écran d'une application) quand l'objectif est une identité propre, pas un gabarit générique. Référence : [art-direction.md](../standards/art-direction.md).

1. **Cadrer** : détecter la stack (skill `stack-detection`) et le design system existant ; ouvrir le point de reprise `.claude/progress/<interface>.md`.
2. **Direction artistique** : agent `art-director` — analyse du secteur, du public, du positionnement et de l'objectif, références, direction (palette, typographie, grille, espacements, images, détails signature). Livrable : `.claude/design/direction-artistique.md`.
3. **Structure de page** : même agent — sections dans l'ordre du parcours du visiteur, gabarit et élément dominant de chacune, schémas de composition desktop et mobile, relecture contre les motifs « IA » à éviter.
4. **Valider la composition avec l'utilisateur** : présenter direction, structure et schémas. **Ne pas développer sans son accord** ; les retours mettent à jour le document.
5. **Fondations** : agent `frontend` — tokens (couleurs, typographies, espacements, rayons, ombres, mouvement) dans le système de style détecté, polices chargées proprement, avant tout composant.
6. **Composants et page** : agent `frontend` — composants dans l'ordre de la structure, contenus réels ou emplacements `[À fournir]`, mobile conçu en même temps que le desktop. `multimedia` si les images ou vidéos demandent un traitement (formats, tailles, chargement).
7. **Vérification visuelle** : agent `ux-ui` — captures à 375, 768, 1280 et 1440 px au minimum (art-direction § 6), conformité à la direction, motifs génériques non justifiés ; agent `accessibility` en parallèle — contrastes, clavier, lecteurs d'écran. Constats → `frontend` corrige → `ux-ui` revérifie.
8. **Revue** : `code-reviewer` ; `seo` si c'est une page publique.
9. **Clore** : écarts restants à la direction et contenus `[À fournir]` listés ; le document de direction reste la référence des écrans suivants.

## Points d'attention

- La complexité visuelle n'est pas la qualité : retirer un effet est souvent la meilleure correction.
- Sans outil de navigateur, la vérification visuelle n'a pas eu lieu : le dire, ne pas l'annoncer comme faite.
- Aucun faux témoignage, faux chiffre, faux logo client ni photo générée présentée comme réelle.
