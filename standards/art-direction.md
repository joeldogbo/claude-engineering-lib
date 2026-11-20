# Direction artistique — concevoir une interface qui a une identité, pas de l'« AI slop »

Fiche lue par l'agent `art-director`, appliquée par `frontend` et contrôlée par `ux-ui`. Elle complète [ui-design.md](ui-design.md) : ui-design fixe les valeurs mesurables (espacements, tailles, contrastes), cette fiche fixe **les choix** qui donnent une personnalité à l'interface. Elle ne dépend d'aucune stack : les exemples Tailwind ou CSS se transposent au système de style du projet.

Principe directeur : **la complexité visuelle n'est pas la qualité.** Une page réussie se reconnaît à quelques décisions fortes, tenues partout, pas à l'accumulation d'effets. Concevoir avec intention, développer avec précision, vérifier avec exigence.

## 0. Profondeur selon le périmètre

| Demande | Ce qu'on déroule |
|---|---|
| Retouche (un bouton, un espacement, une section) | Respect de la direction existante et des § 3 et § 8 ; pas de processus complet |
| Nouvel écran dans une interface qui a déjà sa direction | § 4, § 5 et § 8, à partir de `.claude/design/direction-artistique.md` |
| Création ou refonte d'une page, d'un site, d'une application | Tout, avec validation au § 6 avant le code |
| Audit visuel | § 8, constats P0 / P1 / P2 |

Avant une refonte lourde, annoncer le périmètre et attendre l'accord. Ne jamais écraser des changements non commités de l'utilisateur.

## 1. Comprendre avant de dessiner

Aucune direction artistique sans ces réponses, écrites noir sur blanc, en séparant **faits connus, hypothèses et inconnues** :

| Question | Ce qu'elle décide |
|---|---|
| Type de produit (§ 7), offre, modèle économique | Les priorités de conception |
| Secteur et concurrents directs (3 à 5) | Les codes du secteur à respecter, et ceux qu'on peut casser pour se distinguer |
| Public cible : qui, sur quel appareil, quelle aisance numérique, quelles tâches prioritaires | Densité, taille du texte, ton, part du mobile |
| Positionnement : premium, accessible, technique, chaleureux, institutionnel... | Palette, typographie, quantité de blanc |
| Action principale de chaque page, mesurable | Hiérarchie, place et répétition de l'appel à l'action |
| Contenus réels disponibles : textes, photos, chiffres, témoignages, logo | Ce qu'on peut montrer ; ce qui manque est signalé, jamais inventé |
| Contraintes : charte, design system, stack, accessibilité, performance | Ce qui n'est pas négociable |

Seules les questions bloquantes sont posées ; les hypothèses raisonnables sont annoncées et le travail avance. Une charte ou un design system déjà en place fait foi : la direction s'appuie dessus et ne le remplace pas sans accord. Pour une refonte, l'existant est d'abord audité : ce qu'on garde, corrige, supprime ou repense.

## 2. Les sept décisions d'une direction artistique

Chacune tient en quelques lignes et se justifie par la section 1. Une décision qui ne se justifie pas est décorative : elle saute. Une identité est **propre au projet** : on ne recycle pas la palette ou le style d'un autre projet par habitude.

1. **Concept en une phrase** — l'idée que la page doit faire ressentir (« un atelier d'artisan, précis et calme », « un outil de pilotage dense et fiable »). Trois mots-clés d'ambiance et trois mots à éviter.
2. **Palette à rôles** — `background`, `surface`, `text`, `text-muted`, `border`, `primary`, éventuellement `secondary`, un `accent` **rare** réservé à l'action et aux points d'attention, et `success`, `warning`, `danger`, `info`. Fond souvent neutre teinté, rarement blanc pur ou noir pur. Proportions annoncées (ex. 70 % fond, 25 % texte et structure, 5 % accent). Contrastes vérifiés (ui-design § 4). Une palette « premium » n'est pas un réflexe : elle doit correspondre à la marque et au public.
3. **Typographie** — une ou deux familles choisies pour le concept, la langue, la lisibilité et le poids des fichiers (serif éditoriale, grotesque technique, mono pour les données...), pas la police par défaut par réflexe. Hiérarchie display / titres / corps / légendes / données. Échelle à ratio franc pour les titres (1,25 à 1,5 sur une page éditoriale) : le contraste de taille porte la hiérarchie. Graisses limitées, interlignages, approche des grands titres, longueur de ligne.
4. **Grille et composition** — largeur de contenu, colonnes, gouttières, alignements forts, asymétrie, espace négatif. Un point focal par zone. On ne centre pas tout par défaut et on ne met pas chaque bloc dans une carte. Le rythme alterne pleine largeur, texte étroit, image dominante, liste ou tableau dense, zone de conversion.
5. **Échelle d'espacement et proportions** — une seule échelle (ui-design § 1), des écarts francs entre niveaux : ce qui sépare des sections est nettement plus grand que ce qui sépare des éléments. Bordures, fonds et ombres avec retenue.
6. **Images, icônes et données** — le rôle de chaque image (preuve, ambiance, explication), son traitement (cadrage, ratio, couleur, grain), sa provenance (photos du client, banque d'images sous licence, illustration commandée), son texte alternatif et son chargement. Pas de photos de stock clichés ni d'illustrations de styles mélangés ; une seule famille d'icônes ; pas d'emoji dans une interface professionnelle sauf demande ; un style de graphique cohérent. Jamais d'image générée présentée comme une vraie photo du produit, de l'équipe ou des clients.
7. **Détails signature** — un ou deux gestes reconnaissables, tenus partout : un filet fin, une numérotation de sections, un traitement des liens, une manière d'afficher les chiffres. Deux maximum : au-delà, plus rien n'est signature.

Plus le **mouvement** : il clarifie un changement d'état, guide l'attention ou améliore le ressenti ; transitions courtes et discrètes, pas d'animation d'entrée sur chaque élément, `prefers-reduced-motion` respecté.

**Plusieurs directions ?** Si un vrai choix se pose, proposer **au plus trois** directions réellement différentes (pas trois variantes de couleur), avec avantages et limites de chacune, et recommander clairement l'une d'elles.

## 3. Ce qui fait « généré par IA » — à éviter sauf justification écrite

| Motif | Pourquoi il trahit | À la place |
|---|---|---|
| Grille de 3 cartes identiques icône + titre + deux lignes, répétée de section en section | Aucune hiérarchie : tout a la même importance, donc rien n'en a | Une liste typographique, un tableau, une alternance texte / image, un élément mis en avant et les autres en retrait |
| Chaque bloc dans une carte arrondie et ombrée | Interface en boîtes, aucune respiration | Espace négatif, filets, fonds de section |
| Dégradé violet-bleu ou arc-en-ciel en fond de héros, sur les boutons et les titres | Couleur choisie sans lien avec la marque | Aplats de la palette ; un dégradé seulement s'il sert le concept, discret, une fois |
| Glassmorphism, flous d'arrière-plan, halos, blobs et orbes flottants | Effet sans fonction, coût de performance, contraste fragile | Surfaces pleines, filets, ombres sobres et cohérentes |
| Icône décorative devant chaque titre, icônes flottantes, emoji, badges partout | Remplissage visuel qui ne renseigne pas | Typographie et numérotation ; une icône ou un badge seulement s'il aide à reconnaître ou à décider |
| Héros centré « Titre vague + sous-titre + deux boutons » sur fond abstrait | Gabarit vu mille fois, promesse interchangeable | Un titre concret qui dit ce que c'est et pour qui, une composition qui montre le produit ou la preuve |
| Sections répétitives : héros, logos, 3 avantages, 3 témoignages, tarifs, FAQ, CTA | Structure de modèle, pas d'histoire | Une structure déduite du parcours du visiteur (§ 4) |
| Tout arrondi au maximum, tout ombré (ombres lourdes), tout bordé à la fois | Aucune décision | Un rayon, une ombre, une bordure par rang de composant, en tokens |
| Textes génériques (« Révolutionnez votre workflow », « Solution tout-en-un »), faux chiffres, faux témoignages, faux logos clients ou certifications | Contenu interchangeable, et faux contenus = tromperie | Les vrais contenus du client ; à défaut, des emplacements marqués `[À fournir]` |
| Boutons inertes, liens `#`, fonctionnalités fictives, données de démonstration présentées comme réelles | Façade qui ment à l'utilisateur | Action réelle, ou élément retiré, ou marqué « bientôt » s'il est prévu |
| Police par défaut, poids moyen partout | Hiérarchie plate | Échelle franche, deux à trois graisses au contraste net |
| Animations au défilement sur chaque bloc | Lenteur perçue, distraction | Une ou deux animations qui servent la compréhension |

Un motif de ce tableau est acceptable s'il est **justifié par le concept** et noté dans la direction artistique. Il ne l'est jamais par défaut.

## 4. Structure et parcours

- Arborescence et parcours prioritaires d'abord quand il y a plusieurs pages.
- Partir du parcours du visiteur : ce qu'il doit comprendre, croire puis faire. Chaque section répond à une question qu'il se pose, dans l'ordre où il se la pose.
- Pour chaque section : objectif, contenu réel, gabarit de composition, élément dominant. Deux sections consécutives n'ont pas le même gabarit.
- Wireframes (blocs ASCII ou basse fidélité) **avant** toute décoration.
- L'action principale est visible sans défiler sur desktop et sur mobile, et revient là où la décision se prend ; l'utilisateur sait toujours où il est et quoi faire.
- États prévus pour chaque vue : vide, chargement, erreur, succès, désactivé, permissions insuffisantes, données manquantes.
- Le mobile n'est pas le desktop rétréci : ordre de lecture, taille des titres, recadrage des images et densité sont décidés pour mobile, tablette et desktop.

## 5. Design system

- **Tokens** : couleurs par rôle (§ 2), typographie (familles, tailles, graisses, interlignages), espacements, rayons, ombres, largeurs de contenu, breakpoints, durées et courbes de mouvement. Dans le système de style du projet (thème Tailwind, variables CSS, thème du framework), jamais en valeurs arbitraires dispersées dans les composants.
- **Composants** : inventaire, variantes et états interactifs (repos, survol, focus visible, actif, désactivé, chargement), règles de composition et de responsive, conventions de nommage du projet.
- Un composant n'est générique que s'il partage réellement une structure et un comportement : ne pas tout transformer en composant abstrait.
- Réutiliser les composants et dépendances existants quand ils conviennent ; pas de nouvelle dépendance sans bénéfice clair.

## 6. Livrable et validation avant le code

`.claude/design/direction-artistique.md`, court, dans cet ordre :

1. Diagnostic (et audit de l'existant pour une refonte)
2. Objectif utilisateur et produit, hypothèses annoncées
3. Direction artistique recommandée (et alternatives s'il y en a)
4. Structure et composition des pages, schémas desktop et mobile
5. Design system : tokens et composants
6. Plan d'implémentation
7. Contrôles qualité prévus et risques

Il est présenté à l'utilisateur en séparant **les décisions à valider** des détails tranchés seul ; pas de validation demandée pour chaque détail mineur. Si un aperçu est possible, une planche de tokens rendue. **On ne développe qu'après accord** ; les retours modifient le document, qui reste la référence des écrans suivants. Si l'utilisateur demande directement une implémentation et que le brief suffit, une courte synthèse remplace le long questionnaire.

## 7. Adapter au type de produit

| Type | Priorités |
|---|---|
| Site vitrine, institutionnel | Positionnement, narration, crédibilité, contenu, conversion |
| SaaS, dashboard, back-office | Efficacité, densité maîtrisée, navigation, lisibilité des données, états et permissions |
| E-commerce, marketplace | Découverte, recherche, comparaison, confiance, tunnel d'achat court |
| Fintech, finance | Précision, lisibilité des montants (chiffres tabulaires), transparence, explication des risques, confiance |
| Éducation, formation | Progression visible, pédagogie, motivation, lisibilité, suivi |
| Portfolio, studio créatif | Personnalité, travaux mis en valeur, narration, différenciation |
| Application mobile | Pouce et zones tactiles, conventions de la plateforme (HIG, Material), parcours courts |

## 8. Vérification visuelle et audit

Après développement, la page est **vue à l'écran** (navigateur, captures) aux largeurs de ui-design § 3, au minimum 375, 768, 1280 et 1440 px. On contrôle :

- fidélité à la direction : palette et proportions, échelle typographique, grille, détails signature ;
- hiérarchie, lisibilité, espacements, alignements, rythme : les sections ne se ressemblent pas toutes, le blanc est voulu ;
- absence des motifs du § 3 non justifiés ;
- mobile : hiérarchie, recadrages, action principale, aucun défilement horizontal ;
- états interactifs et parcours, contenus réels (texte long, image absente, chargement) ;
- accessibilité clavier et contrastes (agent `accessibility`) ;
- console sans erreur, build et tests disponibles au vert, poids des médias ;
- cohérence entre les pages.

Constats classés :

- **P0 — Bloquant** : problème d'usage, de lisibilité ou de fonctionnement.
- **P1 — Important** : défaut visuel majeur, incohérence, écart à la direction.
- **P2 — Finition** : détails, micro-interactions, polish.

Chaque constat est concret et justifié (élément, largeur, valeur relevée, valeur cible) : jamais « rendre plus moderne » ou « faire plus premium » sans dire quoi changer. On indique les vérifications **réellement faites** et celles qui restent : sans outil de navigateur, la page n'a pas été vue, seule l'analyse du code a été faite.

## 9. S'inspirer sans copier

Les meilleurs studios et sites de référence (galeries de ui-design § 6) s'étudient pour leurs **principes** : rapport de taille titre / texte, gestion du blanc, nombre de couleurs, rythme des sections. On ne reproduit ni une page, ni une mise en page reconnaissable, ni un logo, une illustration, une police sous licence ou un texte. On ne prétend jamais avoir consulté une page ou une capture qu'on n'a pas vue.

## 10. Définition du succès

- L'interface semble conçue pour ce produit précis, et la marque a une personnalité reconnaissable.
- L'utilisateur comprend où il est et quoi faire ; contenus et données se lisent facilement.
- Les pages ont du rythme sans désordre et restent cohérentes sur mobile et desktop.
- Le code est maintenable et respecte le projet.
- Chaque choix esthétique est justifié, aucun ne vient d'une recette générique.
