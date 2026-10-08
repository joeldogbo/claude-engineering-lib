# Design d'interface — règles mesurables et sources de référence

Fiche lue par l'agent `ux-ui` et le skill `ui-ux-review`. Les valeurs ci-dessous sont des **repères par défaut** : si le projet a un design system (tokens, thème Tailwind, variables CSS, thème Flutter/Material, `theme.ts`), c'est lui qui fait foi, et l'écart à ce système est le premier constat à relever.

## 1. Espacements

- **Échelle unique** basée sur 4 ou 8 px : 4, 8, 12, 16, 24, 32, 48, 64, 96, 128. Toute valeur hors échelle (13 px, 18 px, 27 px...) est un constat, sauf justification optique (alignement d'icône, compensation de line-height).
- **Proximité** : l'espace entre éléments liés est nettement plus petit que l'espace entre groupes (au moins ×1,5 à ×2). Un label est plus près de son champ que du champ précédent.
- **Rythme vertical** : sections de page espacées de 64–128 px sur desktop, 40–64 px sur mobile ; blocs internes 16–32 px.
- **Marges latérales** (gouttières de page) : au moins 16 px sur mobile, 24–32 px sur tablette ; contenu centré avec largeur maximale (souvent 1200–1440 px) au-delà.
- **Padding interne cohérent** : toutes les cartes d'une même liste ont le même padding ; boutons d'une même taille aussi.
- **Grille** : 4 colonnes mobile, 8 tablette, 12 desktop ; gouttières constantes. Les éléments s'alignent sur la grille ou sur un bord commun — pas de décalages de quelques pixels.

## 2. Typographie

- **Échelle typographique** à ratio constant (1,125 à 1,333) ou tokens du design system ; 5 à 7 tailles maximum dans toute l'application.
- **Texte courant** : 16 px minimum sur le web (jamais moins de 14 px pour du texte secondaire, 12 px réservé aux mentions), 17 pt sur iOS, 14–16 sp sur Android. Champs de formulaire à 16 px minimum sur mobile (évite le zoom automatique iOS).
- **Interlignage** : 1,4–1,6 pour le texte courant, 1,1–1,3 pour les titres.
- **Longueur de ligne** : 45–75 caractères (idéal ~66) ; `max-width` en `ch` sur les blocs de lecture.
- **Graisses** : 2 à 3 graisses par famille ; 1 à 2 familles au total. La hiérarchie passe par la taille, la graisse et la couleur, pas par cinq polices.
- **Titres** : un seul `h1` par page, niveaux sans saut ; un titre est plus près du paragraphe qu'il introduit que du précédent.
- **Tailles fluides** : `clamp()` pour les grands titres (ex. `clamp(2rem, 1.2rem + 3vw, 3.5rem)`) plutôt que des sauts brusques aux breakpoints. Unités `rem` pour respecter le réglage de taille du navigateur.
- **Lisibilité** : pas de texte justifié sur le web (rivières), pas de paragraphe entier en majuscules ou en italique, chiffres tabulaires (`font-variant-numeric: tabular-nums`) dans les tableaux et montants.
- **Chargement des polices** : `font-display: swap` ou `optional`, polices de repli aux métriques proches (évite le décalage de mise en page), nombre de fichiers de police limité.
- **Texte et microcopie** : libellés de boutons sous forme de verbe d'action (« Créer le compte », pas « OK »), messages d'erreur qui disent quoi faire, ton et terminologie identiques d'un écran à l'autre.

## 3. Responsive

- **Largeurs à vérifier systématiquement** : 320, 375, 390/414 (mobiles), 768 (tablette portrait), 1024 (tablette paysage / petit portable), 1280, 1440, 1920 px. Vérifier aussi le mode paysage mobile et un zoom navigateur à 200 %.
- **Aucun défilement horizontal** de la page, sauf composant prévu pour (carrousel, tableau large dans un conteneur défilant).
- **Zones tactiles** : 44×44 px minimum (iOS), 48×48 dp (Android), 24×24 px absolu (WCAG 2.5.8) avec espacement suffisant entre deux cibles.
- **Contenu, pas seulement mise en page** : sur mobile, l'action principale reste visible sans chercher ; les tableaux deviennent cartes ou défilent dans leur conteneur ; les menus se replient sans perdre d'entrée.
- **Images** : `srcset`/`sizes` ou équivalent, ratio réservé (`aspect-ratio` ou dimensions) pour éviter les sauts de mise en page ; recadrage adapté au mobile si le sujet devient illisible.
- **Unités et viewport** : `dvh`/`svh` plutôt que `100vh` sur mobile (barres du navigateur), zones sûres (`env(safe-area-inset-*)`) sur écrans à encoche.
- **Requêtes de conteneur** pour les composants réutilisés dans des colonnes de largeurs différentes.

## 4. Couleur et contraste

- Palette en tokens : 1 couleur primaire, 1 éventuelle secondaire, neutres en 8–10 nuances, couleurs sémantiques (succès, alerte, erreur, info).
- La couleur primaire est réservée aux actions principales ; un seul bouton primaire par zone.
- Contraste : 4,5:1 texte courant, 3:1 grand texte et composants d'interface (détail dans l'agent `accessibility`).
- Mode sombre (si présent) : pas un simple négatif — surfaces grises élevées plutôt que noir pur, couleurs désaturées, contraste revérifié.
- L'information n'est jamais portée par la couleur seule (icône ou texte en plus).

## 5. Composants et états

- Chaque élément interactif a ses états : repos, survol, focus visible, actif, désactivé, chargement ; chaque vue ses états vide, chargement (squelette plutôt que spinner plein écran), erreur, succès, contenu partiel.
- Rayons, ombres, bordures et hauteurs de contrôles en tokens, identiques pour des composants de même rang (ex. boutons et champs de même hauteur sur une même ligne).
- Formulaires : labels visibles (pas de placeholder seul), une colonne, erreurs inline à côté du champ, type de clavier adapté sur mobile (`inputmode`, `type`).
- Icônes d'une seule famille, taille et épaisseur de trait cohérentes, alignées optiquement avec le texte.
- Animations : 150–300 ms pour les micro-interactions, courbes d'accélération cohérentes, respect de `prefers-reduced-motion`.

## 6. Sources de référence

Deux familles de sources, à ne pas confondre :

**Règles et design systems** — font foi pour les valeurs mesurables :
- Material Design 3 (m3.material.io), Apple Human Interface Guidelines (developer.apple.com/design), Microsoft Fluent 2, IBM Carbon, Shopify Polaris, Atlassian Design, GOV.UK Design System, DSFR (système de design de l'État français).
- Vercel Geist (vercel.com/geist), Radix UI, shadcn/ui, Tailwind CSS (échelles d'espacement et de typo).
- Recherche UX : Nielsen Norman Group (nngroup.com), Baymard Institute (e-commerce, formulaires), Laws of UX (lawsofux.com).
- Typographie : Butterick's Practical Typography, Utopia (utopia.fyi, échelles fluides), Type Scale (typescale.com).
- Accessibilité et sobriété : WCAG 2.2, RGAA, RGESN.

**Galeries d'inspiration** — pour comparer des tendances, des compositions et des motifs réels du même secteur :
- Sites web : Dribbble, Behance, httpster.net, Land-book, Godly, Awwwards, SiteInspire, Lapa Ninja, One Page Love, Landingfolio, SaaS Landing Page, Minimal Gallery.
- Produits et parcours réels : Mobbin (iOS, Android, web), Page Flows, Refero, UI Sources, Nicely Done.
- Vitrines de référence : vercel.com et ses templates, linear.app, stripe.com — souvent cités pour leurs espacements et leur typographie.

Règles d'usage des galeries :
- **Dribbble et Behance montrent surtout des maquettes** : souvent non responsives, contrastes insuffisants, contenus idéalisés. Elles inspirent une direction ; elles ne valident jamais une valeur. Préférer les sites en production (httpster, Land-book, Godly, Mobbin) pour juger d'un comportement réel.
- Choisir 3 à 5 références **du même type de produit** (SaaS, e-commerce, portfolio, application mobile...) et en dégager des constantes (densité, rythme, échelle typo, traitement mobile), pas copier une page.
- Citer chaque référence par son URL dans la restitution, et préciser ce qu'elle illustre.
- Ne jamais reproduire un design, un logo, une illustration ou un texte protégé : on s'inspire de principes.
- Les pages consultées sont publiques ; aucun code, capture ni contenu du projet n'est envoyé à ces sites.
