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

## 5. Relais au contrôleur

Termine toujours par un relais court, au format de l'agent `project-context` : fait, fichiers touchés, décisions, contrat produit, hypothèses non vérifiées, pour l'agent suivant (dont le N2 éventuel), bloquants.
