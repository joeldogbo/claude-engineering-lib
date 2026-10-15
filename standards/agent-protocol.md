# Protocole commun des agents

S'applique à **tous** les agents de la bibliothèque, existants et futurs. Chaque fichier d'agent y renvoie ; `regulator --audit` signale tout agent qui ne le fait pas.

## 1. Le contrôleur dirige

- Le **contrôleur**, c'est le régulateur (hook qui retient les agents autorisés pour chaque message) et la session principale (qui les lance et consolide leurs résultats).
- Un agent ne lance jamais un autre agent et ne décide pas qui intervient après lui : il le **recommande** dans son relais, avec la raison.
- Un agent reste dans son domaine. Ce qui relève d'un autre agent va dans « Pour l'agent suivant ».

## 2. Langue du projet

- Lis la langue retenue dans `.claude/project-context.md` (section `Langue`). À défaut, déduis-la du README, de la documentation, de l'interface et des messages de commit ; en cas de doute, prends la langue de l'utilisateur.
- Rédige rapports, documentation, textes d'interface et messages de commit dans cette langue. Le code (identifiants) suit la convention déjà en place dans le dépôt, sans la changer.
- Les termes du glossaire du contexte s'imposent, dans la langue où ils y figurent.

## 3. Points de reprise (connexion interrompue)

Un travail de plusieurs étapes doit pouvoir reprendre là où il s'est arrêté, sans rien refaire.

- Avant de commencer, cherche `.claude/progress/<sujet>.md` : s'il existe avec `statut: en cours`, **reprends à la première étape non cochée** après avoir vérifié dans le code que les étapes cochées sont bien faites.
- Sinon, pour toute tâche de 3 étapes ou plus, crée ce fichier avant de modifier quoi que ce soit :

```markdown
# <sujet>
statut: en cours
agent: <nom>   ·   début: AAAA-MM-JJ HH:MM
objectif: <critère de fin, une ligne>

- [x] 1. <étape terminée> — <fichiers touchés>
- [ ] 2. <étape suivante>
- [ ] 3. ...

## Notes de reprise
<décisions prises, commande en cours, ce qu'il faut vérifier en premier>
```

- **Coche chaque étape dès qu'elle est terminée** et note les fichiers touchés : c'est ce fichier, pas la conversation, qui survit à une coupure.
- Une étape doit laisser le projet dans un état cohérent (le code compile, les tests passants le restent). Découpe plus finement plutôt que de laisser une étape à moitié faite.
- À la fin, passe `statut: terminé` ; le contrôleur reporte les décisions durables dans le contexte et supprime le fichier.
- Le régulateur signale à chaque message les fichiers encore `en cours` : le contrôleur propose alors de reprendre.

## 4. Niveaux N1 / N2

Les agents d'une même discipline travaillent par niveaux, enchaînés par le contrôleur :

| N1 — analyse | N2 — correction |
|---|---|
| `security` | `security-fixer` |
| `code-reviewer`, `architect` | `refactoring` |
| `ux-ui`, `accessibility` | `frontend` |
| `deployment-advisor` | `devops` |

- Le N2 déclare son N1 dans son frontmatter : `after: <agent N1>, ...`.
- **N1** analyse, ne modifie rien, et classe ses constats par sévérité. Il termine en indiquant si un passage au N2 est utile et sur quels constats.
- **N2** part du rapport du N1 (fourni par le contrôleur ou dans `.claude/handoffs/`), corrige constat par constat, et le N1 revérifie ensuite. Sans rapport N1 et si la demande consiste à corriger un problème de son domaine, il le signale : le contrôleur lance d'abord le N1.
- Le contrôleur ne lance jamais un N1 et son N2 en parallèle, et propose le N2 à l'utilisateur avant de le lancer quand il modifie du code sensible (sécurité, déploiement).

## 5. Gestion des erreurs

Un agent qui échoue le dit, laisse le projet dans un état cohérent et donne au contrôleur de quoi décider. Il ne masque jamais un échec et ne le contourne pas en affaiblissant une protection.

**Avant d'agir — vérifier les prérequis**
- Outils, fichiers, accès (base, réseau, identifiants) nécessaires : vérifie qu'ils existent (`command -v`, lecture du fichier) avant de lancer le travail qui en dépend.
- Un prérequis manque : n'installe rien globalement et ne crée pas d'identifiant sans accord. Propose la commande exacte, fais ce qui reste possible sans lui, et marque le reste « non vérifié ».
- Entrée invalide ou absente (rapport N1, contexte périmé, fichier cité introuvable, constat qui ne correspond plus au code) : signale-le au lieu d'inventer ou de deviner.

**Pendant — une commande ou une modification échoue**
1. Lis le message d'erreur en entier et formule **une** cause probable, vérifiée dans le code ou la configuration.
2. Corrige cette cause et relance : **deux tentatives corrigées au plus**, jamais la même commande à l'identique. Au-delà, arrête-toi et remonte l'erreur.
3. Interdits pour « faire passer » : `--no-verify`, `--force`, `sudo`, `chmod 777`, désactiver ou supprimer un test, une règle d'analyse, une vérification de signature ou de certificat, effacer un fichier de verrouillage, élargir une permission, avaler l'exception.
4. Erreur réseau ou service tiers indisponible : une nouvelle tentative après un court délai, puis repli (travail hors ligne, `TODO` explicite) — jamais de boucle.
5. Conflit avec une modification de l'utilisateur ou d'un autre agent sur le même fichier : ne l'écrase pas, arrête-toi sur ce fichier et signale le conflit.

**Après — laisser un état cohérent**
- Une étape interrompue est soit **terminée**, soit **annulée** (tes propres changements partiels retirés) : le code compile et les tests qui passaient passent encore. Ne laisse jamais une migration à moitié appliquée, un fichier tronqué ou un commit cassé.
- Avant toute action irréversible (suppression, migration destructive, réécriture d'historique, déploiement, envoi externe) : simulation (`--dry-run`) ou sauvegarde d'abord, accord de l'utilisateur ensuite.
- Mets à jour le point de reprise (section 3) avec l'erreur, ce qui a été tenté et l'état laissé, pour que la reprise ne refasse pas la même tentative.

**Dans le code produit** : aucune erreur avalée en silence ; erreurs attendues traitées avec un message utile à l'utilisateur ; erreurs inattendues journalisées avec leur contexte (sans secret ni donnée personnelle) puis remontées ; ressources libérées et transactions annulées en cas d'échec.

**Erreurs propres à certains domaines**

| Agent | En cas d'échec |
|---|---|
| `database`, `database-builder` | Migration en échec : la ramener à l'état d'avant (`down` ou transaction), ne jamais modifier une migration déjà appliquée ailleurs ; aucune commande destructive pour « repartir propre » sans accord. |
| `git`, `versioning` | Push refusé ou conflit : récupérer et intégrer le distant, jamais de `push --force` sans accord ; tag déjà existant : ne pas le déplacer. |
| `dependencies` | Montée de version qui casse la compilation ou les tests : revenir à la version précédente dans le manifeste **et** le verrouillage, documenter la rupture. |
| `devops`, `deployment-advisor` | Pipeline ou déploiement en échec : retour à la version précédente (rollback) avant tout diagnostic long ; aucun secret dans les journaux. |
| `security-fixer`, `refactoring` | Un correctif casse un test existant : annuler ce correctif, pas le test ; passer au constat suivant et signaler celui-ci. |
| `payments`, `emails`, `integrations` | Appel tiers en échec : nouvelle tentative idempotente ou file d'attente, jamais de double débit, double envoi ni double accès. |
| `incident-response` | Mesure de stabilisation sans effet : la retirer avant d'en essayer une autre, une seule à la fois. |
| `backend`, `frontend`, `api`, `framework-expert` | Compilation ou tests en échec après la modification : corriger ou annuler la modification avant de rendre la main ; API ou version de framework introuvable dans la documentation officielle de la version installée : ne pas l'inventer, le signaler. |
| `api-resilience` | Test de panne qui ne déclenche pas le comportement attendu (retry, disjoncteur, timeout) : le constat est un défaut à corriger, pas un test à assouplir. |
| `testing`, `debugging` | Test instable : l'isoler et en trouver la cause (ordre, temps, état partagé), jamais le relancer jusqu'à ce qu'il passe ni le marquer « ignoré » sans accord ; bug non reproductible : le dire, avec les hypothèses écartées. |
| `load-testing` | Seuils d'erreur ou de latence dépassés pendant un tir : arrêter le tir, jamais contre la production sans accord écrit ; outil de charge absent : proposer la commande d'installation, ne rien lancer d'autre. |
| `ai-chatbot` | Fournisseur indisponible, quota dépassé ou réponse coupée : repli FAQ ou message clair à l'utilisateur final, jamais de réponse inventée ; aucune clé d'API dans les journaux. |
| `multimedia` | Conversion ou compression en échec : garder le fichier d'origine intact, ne jamais remplacer un original avant d'avoir vérifié la version produite. |
| `mcp-developer` | Serveur qui ne démarre pas ou outil refusé par l'inspecteur : ne pas le déclarer dans `.mcp.json` ; jamais de permission élargie pour le faire fonctionner. |
| `knowledge-base` | Graphify absent ou en échec : basculer sur la carte légère `.claude/knowledge/` et le dire ; carte périmée : la marquer comme telle plutôt que de s'y fier. |
| `documentation`, `manuals`, `specifications`, `language` | Commande, chemin ou comportement impossible à vérifier dans le code : l'écrire « non vérifié » ou l'omettre, jamais le présenter comme sûr. |
| `legal`, `privacy`, `consent`, `seo`, `geo`, `prompt-compressor` | Information manquante (raison sociale, finalité, traceur, mot-clé, règle) : laisser un champ `TODO` visible et le lister, ne pas l'inventer ; compression qui perd une règle : l'annuler. |
| `reverse-engineering` | Source inaccessible, archive illisible ou outil d'analyse en échec : question notée « inconnu » avec la raison, source suivante ; conditions d'utilisation ou licence douteuses : arrêt sur ce point et agent `legal` ; jamais de contournement de protection pour obtenir une preuve. |
| `project-context`, `request-history` | Contexte ou historique illisible, contradictoire ou périmé : le signaler et repartir du code, sans écraser le fichier existant. |
| Agents d'analyse (`architect`, `code-reviewer`, `security`, `performance`, `ux-ui`, `accessibility`, `compliance`, `financial-compliance`, `deployment-advisor`, `token-monitor`, `system-monitor`) | Outil d'analyse absent ou en échec : poursuivre en revue manuelle et le dire dans le rapport ; ne jamais conclure « aucun problème » sur un scan qui n'a pas tourné. |

**Installation et mise à jour de la bibliothèque** : `install.sh` et `install.ps1` vérifient les prérequis avant toute écriture, copient à côté puis remplacent, restaurent l'état d'avant sur toute erreur ou interruption et ne remplacent jamais un fichier modifié localement sans `--force` (voir le skill `library-update`). Un agent ne copie jamais lui-même des fichiers de la bibliothèque dans `.claude/` : il passe par l'installateur.

## 6. Relais au contrôleur

Termine toujours par un relais court, au format de l'agent `project-context` : fait, fichiers touchés, décisions, contrat produit, hypothèses non vérifiées, **erreurs** (erreur, cause probable, tentatives, état laissé, action attendue — « aucune » si tout a réussi), pour l'agent suivant (dont le N2 éventuel), bloquants. Un travail partiel est annoncé comme tel, jamais comme terminé.
