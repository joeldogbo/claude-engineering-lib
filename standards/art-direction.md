# Direction artistique — concevoir une interface qui a une identité, pas de l'« AI slop »

Fiche lue par l'agent `art-director`, appliquée par `frontend` et contrôlée par `ux-ui`. Elle complète [ui-design.md](ui-design.md) : ui-design fixe les valeurs mesurables (espacements, tailles, contrastes), cette fiche fixe **les choix** qui donnent une personnalité à l'interface. Elle ne dépend d'aucune stack : les exemples Tailwind ou CSS se transposent au système de style du projet.

Principe directeur : **la complexité visuelle n'est pas la qualité.** Une page réussie se reconnaît à quelques décisions fortes, tenues partout, pas à l'accumulation d'effets.

## 1. Comprendre avant de dessiner

Aucune direction artistique sans ces réponses, écrites noir sur blanc :

| Question | Ce qu'elle décide |
|---|---|
| Secteur et concurrents directs (3 à 5) | Les codes du secteur à respecter, et ceux qu'on peut casser pour se distinguer |
| Public cible : qui, sur quel appareil, dans quel état d'esprit | Densité, taille du texte, ton, part du mobile |
| Positionnement : premium, accessible, technique, chaleureux, institutionnel... | Palette, typographie, quantité de blanc |
| Objectif de la page : une seule action principale mesurable | Hiérarchie, place et répétition de l'appel à l'action |
| Contenus réels disponibles : textes, photos, chiffres, témoignages, logo | Ce qu'on peut montrer ; ce qui manque est signalé, jamais inventé |
| Contraintes : charte existante, design system, accessibilité, performance | Ce qui n'est pas négociable |

Un design system ou une charte déjà en place fait foi : la direction artistique s'appuie dessus et ne le remplace pas sans accord.

## 2. Les sept décisions d'une direction artistique

Chacune tient en quelques lignes et se justifie par la section 1. Une décision qui ne se justifie pas est décorative : elle saute.

1. **Concept en une phrase** — l'idée que la page doit faire ressentir (« un atelier d'artisan, précis et calme », « un outil de pilotage dense et fiable »). Trois mots-clés d'ambiance et trois mots à éviter.
2. **Palette** — une couleur dominante (souvent un neutre teinté, rarement blanc pur ou noir pur), une couleur d'accent **rare** réservée à l'action et aux points d'attention, des neutres en 8 à 10 nuances, les couleurs sémantiques. Proportions annoncées (ex. 70 % fond, 25 % texte et structure, 5 % accent). Contrastes vérifiés (ui-design § 4).
3. **Typographie** — une ou deux familles au caractère choisi pour le concept (une serif éditoriale, une grotesque technique, une mono pour les données...), pas la police par défaut par réflexe. Une échelle à ratio franc pour les titres (1,25 à 1,5 sur une page éditoriale) : le contraste de taille entre le titre principal et le texte courant porte la hiérarchie. Graisses, interlignages, approche (`letter-spacing`) des grands titres.
4. **Grille et composition** — la grille (colonnes, gouttières, largeur maximale), les alignements forts, l'usage de l'asymétrie, la place du blanc. Les sections ne suivent pas toutes le même gabarit : le rythme alterne pleine largeur, texte étroit, image dominante, liste dense.
5. **Échelle d'espacement et proportions** — une seule échelle (ui-design § 1), et des écarts francs entre les niveaux : les espacements qui séparent des sections sont nettement plus grands que ceux qui séparent des éléments.
6. **Images** — le rôle de chaque image (preuve, ambiance, explication), son traitement (cadrage, ratio, couleur, grain), sa provenance (photos du client, banque d'images sous licence, illustration commandée). Une image qui n'apporte rien sort ; jamais d'image générée présentée comme une vraie photo du produit, de l'équipe ou des clients.
7. **Détails signature** — un ou deux gestes reconnaissables, tenus partout : un filet fin, une numérotation de sections, un traitement des liens, une micro-animation à l'entrée, une manière d'afficher les chiffres. Deux maximum : au-delà, plus rien n'est signature.

Plus le mouvement : durées, courbes, ce qui bouge et pourquoi ; rien qui bouge sans raison, `prefers-reduced-motion` respecté.

## 3. Ce qui fait « généré par IA » — à éviter sauf justification écrite

| Motif | Pourquoi il trahit | À la place |
|---|---|---|
| Grille de 3 cartes identiques icône + titre + deux lignes, répétée de section en section | Aucune hiérarchie : tout a la même importance, donc rien n'en a | Une liste typographique, un tableau, une alternance texte / image, un élément mis en avant et les autres en retrait |
| Dégradé violet-bleu ou arc-en-ciel en fond de héros, sur les boutons et les titres | Couleur choisie sans lien avec la marque | Aplats de la palette ; un dégradé seulement s'il sert le concept, discret, une fois |
| Glassmorphism, flous d'arrière-plan, halos lumineux, orbes flottants | Effet sans fonction, coût de performance, contraste fragile | Surfaces pleines, filets, ombres sobres et cohérentes |
| Icône décorative devant chaque titre, emoji dans les titres | Remplissage visuel qui ne renseigne pas | Typographie et numérotation ; une icône seulement si elle aide à reconnaître une action |
| Héros centré « Titre vague + sous-titre + deux boutons » sur fond abstrait | Gabarit vu mille fois, promesse interchangeable | Un titre concret qui dit ce que c'est et pour qui, une composition qui montre le produit ou la preuve |
| Sections répétitives : héros, logos, 3 avantages, 3 témoignages, tarifs, FAQ, CTA | Structure de modèle, pas d'histoire | Une structure déduite du parcours du visiteur (section 4) |
| Tout arrondi au maximum, tout ombré, tout bordé à la fois | Aucune décision | Un rayon, une ombre, une bordure par rang de composant, en tokens |
| Textes génériques (« Révolutionnez votre workflow », « Solution tout-en-un ») et faux chiffres ou faux témoignages | Contenu interchangeable, et faux témoignages = tromperie | Les vrais contenus du client ; à défaut, des emplacements marqués `[À fournir]` |
| Police par défaut + poids moyen partout | Hiérarchie plate | Échelle franche, deux à trois graisses au contraste net |
| Animations au défilement sur chaque bloc | Lenteur perçue, distraction | Une ou deux animations qui servent la compréhension |

Un motif de ce tableau est acceptable s'il est **justifié par le concept** et noté dans la direction artistique. Il ne l'est jamais par défaut.

## 4. Structure de page

- Partir du parcours du visiteur : ce qu'il doit comprendre, croire puis faire. Chaque section répond à une question qu'il se pose, dans l'ordre où il se la pose.
- Pour chaque section : objectif, contenu réel, gabarit de composition, élément dominant. Deux sections consécutives n'ont pas le même gabarit.
- L'action principale est visible sans défiler sur desktop et sur mobile, et revient là où la décision se prend.
- Le mobile n'est pas le desktop empilé : l'ordre de lecture, la taille des titres, le recadrage des images et la densité sont décidés pour lui.

## 5. Validation avant le code

La direction artistique et la structure sont présentées à l'utilisateur **avant tout développement** :

- le document de direction (sections 1 et 2), court ;
- la structure de page (section 4) ;
- un schéma de composition en blocs (ASCII ou wireframe basse fidélité) pour desktop et mobile ;
- si un aperçu visuel est possible, une planche de tokens (couleurs, typographies, espacements) rendue.

On ne développe qu'après accord. Les retours modifient le document, qui reste la référence dans `.claude/design/direction-artistique.md`.

## 6. Vérification visuelle

Après développement, la page est vue à l'écran (navigateur, captures) aux largeurs de ui-design § 3, au minimum 375, 768, 1280 et 1440 px. On contrôle :

- conformité à la direction : palette et proportions, échelle typographique, grille, détails signature ;
- absence des motifs de la section 3 non justifiés ;
- rythme : les sections ne se ressemblent pas toutes, le blanc est voulu ;
- mobile : hiérarchie, recadrages, action principale, aucun défilement horizontal ;
- états et contenus réels (texte long, image absente, chargement).

Sans outil de navigateur, le dire : la page n'a pas été vue, seule l'analyse du code a été faite.

## 7. S'inspirer sans copier

Les meilleurs studios et sites de référence (galeries de ui-design § 6) s'étudient pour leurs **principes** : rapport de taille titre / texte, gestion du blanc, nombre de couleurs, rythme des sections. On ne reproduit ni une page, ni une mise en page reconnaissable, ni un logo, une illustration, une police sous licence ou un texte.
