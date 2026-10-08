---
name: ui-ux-review
description: Revue UI/UX complète — ergonomie, hiérarchie visuelle, espacements, typographie et règles de texte, responsive sur chaque largeur d'écran, couleur, états des composants, cohérence avec le design system, comparaison avec des références (design systems, Dribbble, Behance, httpster, Land-book, Vercel...). Utiliser pour une revue d'interface, avant de livrer un écran/composant, ou quand l'utilisateur demande un avis UX/UI.
---

# Revue UI/UX

Référence : [ui-design.md](../../standards/ui-design.md) (valeurs par défaut et sources). Le design system du projet prime toujours sur ces valeurs.

## Étape 1 — Contexte

1. Détecter la stack front (skill `stack-detection`) et **le design system en place** : tokens, thème Tailwind (`tailwind.config.*`, `@theme`), variables CSS, bibliothèque de composants (MUI, shadcn/ui, Vuetify, Angular Material...), thème Flutter/SwiftUI/Compose.
2. Identifier le type de produit (SaaS, e-commerce, vitrine, portfolio, back-office, application mobile) et l'action principale de chaque écran revu.

## Étape 2 — Références externes

Si l'accès web est disponible, consulter 3 à 5 références **du même type de produit**, comme indiqué dans la section « Sources de référence » du standard :
- un ou deux design systems pour les valeurs (Material, Apple HIG, Geist de Vercel, Polaris, DSFR...) ;
- des galeries de sites réels pour les compositions (httpster.net, Land-book, Godly, Mobbin...) ;
- Dribbble et Behance pour la direction visuelle uniquement, jamais pour valider une mesure.

Sans accès web, s'appuyer sur le standard et dire que les références n'ont pas été consultées. N'envoyer aucun contenu du projet à ces sites.

## Étape 3 — Analyse

Pour chaque écran ou composant :

1. **Ergonomie** : parcours de l'action principale évident, nombre d'étapes minimal, pas d'impasse, retour possible, état courant identifiable.
2. **Hiérarchie visuelle** : l'élément le plus important attire l'œil en premier (taille, contraste, position) ; un seul bouton primaire par zone.
3. **Espacements** : valeurs sur l'échelle du projet (relever chaque valeur hors échelle avec fichier:ligne), loi de proximité, rythme vertical régulier, alignement sur la grille, paddings identiques pour des composants de même rang.
4. **Typographie et texte** : nombre de tailles et de graisses, taille minimale du texte courant, interlignage, longueur de ligne, hiérarchie des titres, unités relatives, tailles fluides, chargement des polices, libellés d'action, messages d'erreur utiles, terminologie constante.
5. **Responsive** : comportement à 320, 375, 768, 1024, 1280, 1440 et 1920 px, en paysage mobile et à 200 % de zoom. Défilement horizontal, zones tactiles, action principale visible sur mobile, tableaux et menus, images, `100vh` sur mobile, zones sûres.
6. **Couleur** : palette en tokens, primaire réservée aux actions, couleurs sémantiques, mode sombre, information jamais portée par la couleur seule.
7. **Composants et états** : survol, focus, actif, désactivé, chargement ; vues vides, en erreur, en chargement ; formulaires (labels visibles, erreurs inline, clavier mobile) ; icônes et animations cohérentes.
8. **Cohérence** : même composant, même apparence partout ; aucun style ad hoc qui contourne le design system.

**Vérification à l'écran** : si un outil de navigateur est disponible (Playwright, navigateur intégré, Chrome) et que l'application tourne en local, capturer chaque écran aux largeurs listées plutôt que de juger uniquement le code. Sinon, analyser le CSS/les styles et le préciser dans la restitution.

## Restitution

1. Synthèse : note par axe (espacements, typographie, responsive, couleur, composants, ergonomie) en ✅ / ⚠️ / ❌.
2. Constats priorisés par impact sur la tâche principale, chacun avec : écran ou composant, fichier:ligne, largeur d'écran concernée si responsive, règle enfreinte, correctif proposé avec la valeur cible (token ou valeur de l'échelle).
3. Références consultées : URL et ce que chacune illustre.
4. Pour le contraste, le clavier et les lecteurs d'écran, renvoyer vers l'agent `accessibility`.
