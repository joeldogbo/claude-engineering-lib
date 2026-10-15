---
name: reverse-engineering
description: Méthode pour comprendre comment une application existante réalise une fonctionnalité et la reproduire en mieux dans le projet — liste de questions, preuves adaptées au type de cible (site, appli web, Electron, mobile, bureau, open source), registre observé/déduit/inconnu, forces et faiblesses de la référence, fiche de fonctionnalité et critères de vérification. Utiliser quand l'utilisateur veut « la même fonctionnalité que dans telle appli », s'inspirer d'un produit existant ou comprendre son fonctionnement.
argument-hint: [application] [fonctionnalité]
---

# Rétro-ingénierie fonctionnelle

Méthode inspirée de [REA](https://github.com/morluto/rea) (« Reverse Engineer Anything ») : partir d'une fonctionnalité vue dans une application, en établir le fonctionnement **preuves à l'appui**, puis la reconstruire dans le projet et vérifier la reconstruction contre une liste finie de comportements. Elle fonctionne sans outil particulier ; REA, s'il est installé, l'outille pour les cibles compilées.

## 1. Cadrer

- **Cible** : application, version, plateforme, fonctionnalité exacte. L'utilisateur la désigne ; en cas d'ambiguïté (plusieurs installations, plusieurs versions), demande.
- **Droit d'examiner** : installation de l'utilisateur, site public, logiciel libre (note la licence). Conditions d'utilisation qui interdisent l'analyse, protection à contourner, données personnelles en jeu : arrête-toi sur ce point et signale-le (agent `legal`).
- **Ce que l'utilisateur veut garder** : le comportement, l'ergonomie, la performance perçue, un format d'échange ? Ce qu'il veut faire mieux ?
- Si la tâche fait 3 étapes ou plus, ouvre le point de reprise `.claude/progress/reverse-<application>-<fonctionnalité>.md`.

## 2. Questions avant outils

Écris la liste des questions, chacune avec la preuve qui y répondrait et l'endroit où la chercher. Exemple pour « la recherche instantanée de l'appli Notes » :

| Question | Preuve attendue | Où |
|---|---|---|
| Recherche locale ou serveur ? | Requêtes émises pendant la frappe | Enregistrement réseau (HAR) |
| Quand se déclenche-t-elle ? | Délai entre frappe et requête/affichage | Observation chronométrée |
| Quels champs sont indexés ? | Résultats sur titre, corps, étiquettes | Scénario de test manuel |
| Tolérance aux fautes, accents ? | Résultats pour « cafe » / « café » / « cafr » | Scénario de test manuel |
| Comportement sans résultat, hors ligne, liste longue ? | Écrans et messages | Observation |

Une question sans preuve possible reste *inconnue* : ne la comble pas par une supposition.

## 3. Choisir la source de preuve, de la moins coûteuse à la plus profonde

| Cible | Sources, dans l'ordre | Outils (si présents, sinon le dire) |
|---|---|---|
| Toute cible | Documentation publique, notes de version, articles d'aide, billets techniques, brevets publiés, API publique documentée | WebSearch, WebFetch |
| Logiciel libre | Code source et historique (commits, issues) — **licence notée** | Lecture du dépôt |
| Site ou appli web | Interface observée, arbre d'accessibilité, requêtes réseau, scripts publics et cartes de source publiées, stockage local | Navigateur et DevTools, HAR, Lighthouse ; REA : observation navigateur, captures HAR |
| Appli Electron ou JavaScript de bureau | Archive `app.asar` extraite : modules, imports, passerelles IPC preload ↔ processus principal | `npx asar extract` ; REA : `analyze_javascript_application` |
| Appli mobile | Manifeste, ressources, chaînes, classes décompilées (Android) ; iOS : surtout l'observation | apktool, JADX ; REA : outils Android |
| Bureau .NET ou natif | Métadonnées, assemblages, pseudocode | ILSpy ; Ghidra, IDA, Hopper ; REA |
| Base locale de l'appli | Schéma des tables, index | Client SQLite en lecture ; REA : `inspect_sqlite_database` |

Règles :
- **Vue d'ensemble d'abord**, puis une seule question précise à la fois ; ne relance pas une analyse identique.
- **Statique avant exécution.** N'exécute ou n'automatise la cible que si l'analyse statique ne peut pas répondre, sur l'instance locale de l'utilisateur, avec un scénario déclaré (actions, données de test). Jamais contre les serveurs d'un tiers au-delà d'un usage normal.
- **Rien d'installé sans accord.** Outil absent : propose la commande exacte et continue avec les autres sources.
- **REA (facultatif)** : si ses outils MCP sont présents dans la session, utilise-les selon leur propre skill (routage par type de cible, résultats résumés d'abord, identifiants de preuve à citer). S'ils sont absents et qu'une question exige l'analyse d'un binaire ou d'un paquet, propose d'abord le plan en simulation : `npx -y rea-agents@latest setup --client claude_code --dry-run --json`, puis, après accord, la même commande avec `--yes` et un redémarrage de la session. Ne propose jamais l'installation d'un moteur (Hopper, Ghidra, IDA) sans accord explicite.

## 4. Tenir le registre des preuves

Chaque constat entre dans le registre de la fiche avec un identifiant (`P1`, `P2`...) :

| Id | Constat | Nature | Source | Confiance | Limite |
|---|---|---|---|---|---|
| P1 | La requête part 300 ms après la dernière frappe | observé | HAR, entrées 12 à 19 | haute | mesuré sur 5 frappes |
| P2 | Index plein texte côté client | déduit | P1 (aucune requête pour 3 recherches sur 4) + module `search-index` dans l'ASAR | moyenne | non vérifié hors ligne |
| P3 | Gestion des accents | inconnu | — | — | à tester : « cafe » vs « café » |

- *Observé* : vu, mesuré ou lu, avec sa source exacte. *Déduit* : raisonnement explicite, preuves citées. *Inconnu* : ce qui permettrait de trancher.
- Une recherche sans résultat est **bornée** : « absent des 40 modules examinés », jamais « n'existe pas ».
- Une analyse statique ne prouve pas un comportement à l'exécution ; une corrélation n'est pas une cause.

## 5. Juger la référence, puis faire mieux

Passe la fonctionnalité au crible des standards de la bibliothèque et note forces et faiblesses, chacune liée au registre :
- ergonomie et états (vide, chargement, erreur, hors ligne) — [ui-design.md](../../standards/ui-design.md) ;
- accessibilité (clavier, lecteur d'écran, contraste) ;
- performance (temps de réponse, volume de données, coût réseau) ;
- sécurité et confidentialité (données envoyées, stockées, journalisées) — [owasp-top10.md](../../standards/owasp-top10.md) ;
- gestion des erreurs et cas limites.

Les améliorations proposées sont des **choix de conception**, présentés séparément des observations, avec leur coût.

## 6. Adapter au projet

- Stack détectée (skill `stack-detection`), conventions et modules existants : où la fonctionnalité s'insère, ce qui existe déjà et peut être réutilisé.
- Comportements à reproduire, rédigés en critères d'acceptation (« Étant donné… quand… alors… »), chacun relié aux preuves qui le fondent.
- **Salle blanche** : la fiche décrit des comportements, pas du code ; l'implémentation s'écrit à partir de la fiche, pas d'un code décompilé. Aucun texte, visuel, icône, police ou marque de la référence. Code libre repris seulement si la licence est compatible avec celle du projet, avec attribution.

## 7. Vérifier la reconstruction

- Liste finie de comportements vérifiables, issue des critères d'acceptation, transformée en tests par l'agent `testing`. Un succès ne couvre que ces comportements, pas une équivalence générale avec la référence.
- Quand c'est possible, mêmes scénarios sur la référence et sur le projet (mêmes données de test), résultats comparés dans la fiche.

## 8. Clore

Reprends la liste de questions : chacune est *résolue*, *partiellement résolue* ou *non résolue*, avec ses preuves. Une étude n'est pas annoncée complète tant que des questions nécessaires restent ouvertes. Restitue la fiche ([fiche-fonctionnalite.md](../../templates/fiche-fonctionnalite.md)) et le relais.

## En cas d'erreur

Applique la gestion des erreurs du [protocole commun](../../standards/agent-protocol.md#5-gestion-des-erreurs). En particulier : page qui ne se charge pas, archive illisible, outil d'analyse en échec → note la question *inconnue*, dis pourquoi, passe à la source suivante ; ne conclus jamais sur une analyse qui n'a pas tourné.
