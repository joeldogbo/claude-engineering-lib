# claude-engineering-lib

Bibliothèque d'agents, skills, standards, templates et workflows pour [Claude Code](https://claude.com/claude-code), **agnostique de toute stack** — copiable telle quelle dans n'importe quel dépôt (Laravel, Symfony, Django, Spring Boot, ASP.NET, Node, NestJS, Express, React, Vue, Angular, Svelte, Flutter, React Native, Electron, Python, Go, Rust, Java, C#, C++, Kotlin, Swift...).

Chaque agent et chaque skill est organisé par **discipline d'ingénierie** (architecture, sécurité, performance, tests...), jamais par framework. Avant d'agir, ils détectent la stack réelle du projet et adaptent leurs recommandations en conséquence.

## Installation

### macOS / Linux / WSL / Git Bash

```bash
curl -fsSL https://raw.githubusercontent.com/joeldogbo/claude-engineering-lib/main/install.sh | bash
```

### Windows (PowerShell)

```powershell
iwr -useb https://raw.githubusercontent.com/joeldogbo/claude-engineering-lib/main/install.ps1 | iex
```

Le script télécharge la dernière release (ou la branche `main` si aucune release n'existe encore) et copie les dossiers `agents/`, `skills/`, `standards/`, `templates/`, `workflows/` ainsi que `CLAUDE.md` dans le dossier `.claude/` du dépôt courant — là où Claude Code les découvre — **sans écraser** tes modifications. Le `CLAUDE.md` propre au projet, à la racine, n'est pas touché : Claude Code charge les deux.

Options utiles :

```bash
# Mettre à jour une installation existante (échoue s'il n'y en a pas)
curl -fsSL .../install.sh | bash -s -- --update

# Voir ce qui changerait, sans rien écrire
curl -fsSL .../install.sh | bash -s -- --dry-run

# Remplacer aussi les fichiers modifiés localement (anciennes versions sauvegardées)
curl -fsSL .../install.sh | bash -s -- --force

# Installer une version précise
curl -fsSL .../install.sh | bash -s -- --version v1.2.0

# Installer dans un autre dossier
curl -fsSL .../install.sh | bash -s -- --dir ./mon-projet
```

Équivalents PowerShell : `-Update`, `-DryRun`, `-Force`, `-Version v1.2.0`, `-TargetDir ./mon-projet` (ou `$env:CLAUDE_LIB_UPDATE=1`, `$env:CLAUDE_LIB_DRY_RUN=1` avant `iwr ... | iex`). Pour les passer à l'installation en une commande :

```powershell
& ([scriptblock]::Create((iwr -useb https://raw.githubusercontent.com/joeldogbo/claude-engineering-lib/main/install.ps1))) -Force -Version v1.2.0
```

Depuis l'invite de commandes Windows (`cmd.exe`), où `iwr` n'existe pas :

```bat
powershell -NoProfile -ExecutionPolicy Bypass -Command "iwr -useb https://raw.githubusercontent.com/joeldogbo/claude-engineering-lib/main/install.ps1 | iex"
```

### Projet qui a déjà ses propres agents

L'installation fonctionne aussi dans un projet qui a déjà un dossier `.claude/` :

| Déjà présent dans le projet | Résultat |
|---|---|
| `.claude/CLAUDE.md` | Conservé. Les consignes de la bibliothèque sont copiées dans `.claude/claude-lib.md`, et une ligne `@claude-lib.md` est ajoutée à la fin de ton fichier pour les importer. Sans cette ligne, Claude ne lance pas les agents tout seul : ne la retire pas (une relance la remet). |
| Agent portant le même nom qu'un agent de la bibliothèque | Le tien est conservé, celui de la bibliothèque est mis dans `.claude/updates/agents/<nom>.md.new`. `--force` le met à la place (le tien est sauvegardé), sinon renomme le tien et relance. |
| Agents sans champ `triggers:` | Ils restent utilisables : le régulateur les signale à chaque message comme « agents propres au projet », et Claude les lance si leur description correspond. Ajoute-leur un `triggers:` pour qu'ils soient sélectionnés comme les autres. |
| `.claude/settings.json` | Conservé ; le hook du régulateur y est ajouté. Si la fusion est impossible, il est écrit dans `.claude/settings.regulator.json`, à recopier dans `settings.json`. |

Redémarre ensuite la session Claude Code : les agents ne sont chargés qu'au démarrage.

Compatibilité, vérifiée à chaque modification des installateurs par la CI ([`install.yml`](.github/workflows/install.yml)) : `install.sh` sous Linux, macOS et Git Bash (Windows) ; `install.ps1` sous Windows PowerShell 5.1 et PowerShell 7 (Windows, Linux, macOS). Si PowerShell refuse d'exécuter un `install.ps1` téléchargé (politique d'exécution), utiliser la commande `iwr ... | iex` ci-dessus, qui n'y est pas soumise.

### Choisir les agents à installer

Sans option, l'installateur **détecte le type de projet** (Flutter, React Native, Electron, front web, Laravel, Django, API Node, Go...) et propose dans un menu le profil correspondant, une installation complète, ou un choix sur mesure par groupe et par agent. Hors terminal (CI, `--yes`), il retient le profil détecté, et tous les agents si rien n'est reconnu.

| Profil (`--type`) | Pour | Groupes installés |
|---|---|---|
| `web` | Site ou application web | tous |
| `mobile` | Flutter, React Native, natif | tous sauf `seo` |
| `api` | API ou service backend sans interface | core, docs, backend, security, performance, ops, compliance, tooling |
| `desktop` | Electron, Tauri, WPF... | core, docs, ui, security, performance, ops, tooling |
| `library` | Bibliothèque, CLI, script | core, docs, security, performance, ops, tooling |

Le groupe `core` (contexte partagé, langue, architecture, revue, refactoring, tests, débogage, git, versions, cahier des charges) est **toujours installé**, ainsi que le régulateur, les skills, standards, templates et workflows. Les groupes et profils sont définis dans [`profiles.conf`](profiles.conf) ; chaque agent déclare le sien (`group:`).

```bash
curl -fsSL .../install.sh | bash -s -- --type mobile              # profil d'un type de projet
curl -fsSL .../install.sh | bash -s -- --groups security,seo      # socle + groupes choisis
curl -fsSL .../install.sh | bash -s -- --agents payments,manuals  # ajouter des agents plus tard
curl -fsSL .../install.sh | bash -s -- --all                      # tous les agents
```

Équivalents PowerShell : `-Type mobile`, `-Groups security,seo`, `-Agents payments,manuals`, `-All`, `-Yes` ; pour l'installation en une commande, `$env:CLAUDE_LIB_TYPE='mobile'` (ou `CLAUDE_LIB_GROUPS`, `CLAUDE_LIB_AGENTS`, `CLAUDE_LIB_ALL=1`) avant `iwr ... | iex`. Une relance garde la sélection déjà installée et y ajoute ce qui est demandé.

### Mettre à jour

Relancer la commande d'installation dans un projet déjà équipé le **met à jour** (`--update` / `-Update` l'exige, `--dry-run` / `-DryRun` montre le plan sans rien écrire). Depuis Claude Code, `/library-update [version]` fait la simulation, applique après ton accord puis t'aide à fusionner les conflits.

L'installateur note dans `.claude/.claude-lib.manifest` la version installée, les groupes choisis et l'empreinte de chaque fichier. À la mise à jour, chaque fichier suit ces règles :

| Situation | Résultat |
|---|---|
| Inchangé chez toi, nouvelle version dans la bibliothèque | Remplacé ; ancienne version dans `.claude/backups/<date>/` |
| Modifié chez toi, inchangé dans la bibliothèque | Conservé |
| Modifié chez toi **et** dans la bibliothèque | Conservé ; nouvelle version dans `.claude/updates/<fichier>.new`, à fusionner (`--force` remplace, après sauvegarde) |
| Retiré de la bibliothèque | Supprimé s'il n'a pas été modifié (sauvegardé), conservé sinon |
| Agent que tu as supprimé | Pas réinstallé, sauf `--agents <nom>` |
| Nouvel agent d'un groupe installé | Ajouté |
| Tes propres fichiers | Jamais touchés |
| Version demandée plus ancienne que l'installée | Refusé, sauf `--force` |
| Installation antérieure au manifeste | Fichiers différents remplacés après sauvegarde, sauf `CLAUDE.md` (mis en conflit) |

**En cas d'erreur**, rien n'est laissé à moitié : prérequis (outils, droits d'écriture, version, archive) vérifiés avant toute écriture ; fichiers copiés à côté puis remplacés ; toute erreur ou interruption (Ctrl+C) restaure l'état d'avant ; chaque fichier écrit est revérifié par son empreinte ; un verrou empêche deux installations simultanées. Les 5 dernières sauvegardes sont gardées, hors de git. Les deux installateurs partagent le même manifeste : on peut installer avec l'un et mettre à jour avec l'autre.

### Installation manuelle

Cloner le dépôt et copier les dossiers qui t'intéressent :

```bash
git clone https://github.com/joeldogbo/claude-engineering-lib.git
mkdir -p mon-projet/.claude
cp -r claude-engineering-lib/{agents,skills,standards,templates,workflows,CLAUDE.md} mon-projet/.claude/
```

## Contenu

Voir [CLAUDE.md](CLAUDE.md) pour l'index complet : 48 agents (rétro-ingénierie fonctionnelle d'applications existantes, contexte partagé du projet, demandes déjà faites, base de connaissances du code, multimédia, dépendances et montées de version, incidents de production, serveurs MCP, langue du projet, manuels développeur/utilisateur/déploiement, cahier des charges, architecture, création de base de données, robustesse d'API, backend, frontend, frameworks UI, sécurité, correction de failles, performance, tests de charge, tests, conseil en déploiement, devops, git, versionnement, conformité, paiements, intégrations, chatbot IA, e-mails, compression de prompts, consommation de jetons, santé du poste...), 23 skills (dont les données hiérarchiques, avec requêtes vérifiées, la rétro-ingénierie fonctionnelle et la mise à jour de la bibliothèque), 12 standards de référence (dont le protocole commun des agents), 7 templates et 15 workflows invocables via `/workflow <nom>`.

## Utilisation

Une fois installée dans un projet, la bibliothèque est chargée automatiquement par Claude Code via `.claude/CLAUDE.md`. **Décris simplement ta tâche** : à la fin de ton message, Claude choisit et lance lui-même les agents concernés (par exemple `backend` + `database` pour une nouvelle fonctionnalité avec migration, puis `code-reviewer` et `security` sur le résultat). Inutile d'écrire « lance les agents ».

### Le régulateur

Avec des dizaines d'agents, les laisser chacun décider de se lancer mènerait au désordre. Un seul contrôleur décide donc : le **régulateur**, un hook Claude Code (`.claude/hooks/regulator.sh`, ou `regulator.ps1` sous Windows) que l'installateur enregistre dans `.claude/settings.json`.

- **Obligatoire et automatique** : il s'exécute sur chaque prompt, avant que Claude le lise, et ne consomme aucun jeton de modèle.
- **Il tranche** : il compare le message au champ `triggers:` de chaque agent et ajoute au contexte la liste des agents retenus (quatre au plus), ou « aucun agent ». Claude ne lance que ceux-là.
- **Il se met à jour seul** : il relit `.claude/agents/` à chaque prompt ; un nouvel agent doté d'un champ `triggers:` est pris en compte immédiatement.
- **Il se vérifie** : `bash .claude/hooks/regulator.sh --audit` échoue si un agent n'a pas de déclencheurs, de groupe ou de lien vers le [protocole commun](standards/agent-protocol.md), ou si son `after:` vise un agent inexistant ; il signale aussi les déclencheurs partagés. La CI l'exécute à chaque modification d'agent : la règle vaut pour les anciens agents comme pour les nouveaux. Un agent qui doit céder la place à un autre déclare des `excludes:` (par exemple `performance` s'efface devant `system-monitor` quand on parle de « mon PC »).
- **Il enchaîne les niveaux N1 → N2** : un agent d'analyse (N1) relève, l'agent de correction associé (N2) corrige à partir de son rapport, puis le N1 revérifie — `security` → `security-fixer`, `code-reviewer` et `architect` → `refactoring`, `ux-ui` et `accessibility` → `frontend`, `deployment-advisor` → `devops`. Le régulateur affiche la chaîne pour que Claude les lance l'un après l'autre, jamais en parallèle.
- **Il reprend le travail interrompu** : pour une tâche de plusieurs étapes, l'agent tient un point de reprise dans `.claude/progress/<sujet>.md` et coche chaque étape terminée. Après une coupure de connexion ou une session fermée, le régulateur le signale au message suivant et Claude reprend à la première étape non cochée, sans refaire le reste. Ces fichiers sont locaux : ajoute `.claude/progress/` au `.gitignore` du projet si tu ne veux pas les versionner.
- **Il repère les demandes répétées** : chaque message est comparé aux 200 précédents du projet. S'il reprend au moins 75 % des mots d'un message déjà envoyé, le régulateur le signale avec sa date, et l'agent `request-history` vérifie ce qui est déjà fait (git, points de reprise, fichiers) avant de ne faire que ce qui manque. Le journal `.claude/hooks/prompts.log` reste local, est ignoré par git et ne garde que des mots normalisés, pas le texte des messages.
- **Il impose la langue du projet** : l'agent `language` inscrit dans `.claude/project-context.md` la langue de la documentation, de l'interface et des commits ; tous les agents l'appliquent.

### Voir les agents travailler

Le mod `agents-status` (`.claude/skills/agents-status/`), chargé automatiquement par Claude Code dans les sessions interactives, montre en permanence le travail des agents :

- **sous la zone de saisie**, la ligne d'état affiche `◆ Agents retenus : backend, api` après chaque message, puis `▶ Agents au travail : backend` tant qu'un agent tourne ;
- **dans la ligne d'activité animée**, le texte devient « Agent backend au travail… » ;
- **dans le fil de la conversation**, Claude annonce les agents lancés et chaque appel d'agent porte son nom (`backend : endpoint de présence`).

Les agents, comme ce mod, ne sont chargés qu'**au démarrage d'une session** : après une installation, redémarre Claude Code (ou recharge la fenêtre VS Code). Le régulateur écrit sa sélection dans `.claude/hooks/regulator.last`, ignoré par git, que le mod relit.

Pour économiser des jetons, écris `/prompt-writer <ton brouillon>` : Claude transforme une demande floue en prompt clair avant de l'exécuter, ce qui évite les allers-retours et le travail refait. Pour alléger durablement les instructions relues à chaque session, demande simplement de compresser `CLAUDE.md` ou un agent : l'agent `prompt-compressor` s'en charge.

Pour forcer un agent précis, nomme-le (« utilise l'agent `performance` »). Les workflows complets se lancent avec `/workflow <nom>`, par exemple `/workflow feature-development` ou `/workflow security-audit`.

## Releases

Les [releases](https://github.com/joeldogbo/claude-engineering-lib/releases) marquent des versions stables (`vMAJOR.MINOR.PATCH`, voir [standards/semver-conventional-commits.md](standards/semver-conventional-commits.md)). Les scripts d'installation ciblent la dernière release par défaut, plutôt que `main` qui peut être en cours de modification — ça évite d'installer une version instable et permet de savoir précisément ce qui change d'une version à l'autre (changelog généré automatiquement).

## Étendre la bibliothèque

- Nouvel agent : ajouter `agents/<nom>.md`, sans toucher aux fichiers existants.
- Nouveau skill : ajouter `skills/<nom>/SKILL.md`.
- Nouveau standard/template : ajouter le fichier et le référencer depuis les skills concernés.
- Nouveau workflow : ajouter `workflows/<nom>.md` et l'ajouter au skill `workflow`.

## Sécurité du dépôt

Ce dépôt est public (lecture libre nécessaire pour l'installation en une commande). La protection porte sur l'**écriture** :

- Branch protection sur `main` (review obligatoire, pas de push direct)
- 2FA activée sur les comptes avec accès
- Secret scanning et Dependabot activés
- Aucun secret ni credential dans ce dépôt

## Licence

[MIT](LICENSE)
