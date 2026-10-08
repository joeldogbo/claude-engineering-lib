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

Le script télécharge la dernière release (ou la branche `main` si aucune release n'existe encore) et copie les dossiers `agents/`, `skills/`, `standards/`, `templates/`, `workflows/` ainsi que `CLAUDE.md` dans le dossier `.claude/` du dépôt courant — là où Claude Code les découvre — **sans écraser** ce qui existe déjà. Le `CLAUDE.md` propre au projet, à la racine, n'est pas touché : Claude Code charge les deux.

Options utiles :

```bash
# Écraser les fichiers existants
curl -fsSL .../install.sh | bash -s -- --force

# Installer une version précise
curl -fsSL .../install.sh | bash -s -- --version v1.2.0

# Installer dans un autre dossier
curl -fsSL .../install.sh | bash -s -- --dir ./mon-projet
```

Équivalents PowerShell : `-Force`, `-Version v1.2.0`, `-TargetDir ./mon-projet`. Pour les passer à l'installation en une commande :

```powershell
& ([scriptblock]::Create((iwr -useb https://raw.githubusercontent.com/joeldogbo/claude-engineering-lib/main/install.ps1))) -Force -Version v1.2.0
```

Depuis l'invite de commandes Windows (`cmd.exe`), où `iwr` n'existe pas :

```bat
powershell -NoProfile -ExecutionPolicy Bypass -Command "iwr -useb https://raw.githubusercontent.com/joeldogbo/claude-engineering-lib/main/install.ps1 | iex"
```

Compatibilité, vérifiée à chaque modification des installateurs par la CI ([`install.yml`](.github/workflows/install.yml)) : `install.sh` sous Linux, macOS et Git Bash (Windows) ; `install.ps1` sous Windows PowerShell 5.1 et PowerShell 7 (Windows, Linux, macOS). Si PowerShell refuse d'exécuter un `install.ps1` téléchargé (politique d'exécution), utiliser la commande `iwr ... | iex` ci-dessus, qui n'y est pas soumise.

### Installation manuelle

Cloner le dépôt et copier les dossiers qui t'intéressent :

```bash
git clone https://github.com/joeldogbo/claude-engineering-lib.git
mkdir -p mon-projet/.claude
cp -r claude-engineering-lib/{agents,skills,standards,templates,workflows,CLAUDE.md} mon-projet/.claude/
```

## Contenu

Voir [CLAUDE.md](CLAUDE.md) pour l'index complet : 39 agents (contexte partagé du projet, cahier des charges, architecture, création de base de données, robustesse d'API, backend, frontend, frameworks UI, sécurité, correction de failles, performance, tests de charge, tests, conseil en déploiement, devops, git, versionnement, conformité, paiements, intégrations, chatbot IA, e-mails, compression de prompts, consommation de jetons, santé du poste...), 20 skills, 11 standards de référence, 6 templates et 14 workflows invocables via `/workflow <nom>`.

## Utilisation

Une fois installée dans un projet, la bibliothèque est chargée automatiquement par Claude Code via `.claude/CLAUDE.md`. **Décris simplement ta tâche** : à la fin de ton message, Claude choisit et lance lui-même les agents concernés (par exemple `backend` + `database` pour une nouvelle fonctionnalité avec migration, puis `code-reviewer` et `security` sur le résultat). Inutile d'écrire « lance les agents ».

### Le régulateur

Avec des dizaines d'agents, les laisser chacun décider de se lancer mènerait au désordre. Un seul contrôleur décide donc : le **régulateur**, un hook Claude Code (`.claude/hooks/regulator.sh`, ou `regulator.ps1` sous Windows) que l'installateur enregistre dans `.claude/settings.json`.

- **Obligatoire et automatique** : il s'exécute sur chaque prompt, avant que Claude le lise, et ne consomme aucun jeton de modèle.
- **Il tranche** : il compare le message au champ `triggers:` de chaque agent et ajoute au contexte la liste des agents retenus (quatre au plus), ou « aucun agent ». Claude ne lance que ceux-là.
- **Il se met à jour seul** : il relit `.claude/agents/` à chaque prompt ; un nouvel agent doté d'un champ `triggers:` est pris en compte immédiatement.
- **Il se vérifie** : `bash .claude/hooks/regulator.sh --audit` signale les agents sans déclencheurs et les déclencheurs partagés entre plusieurs agents. Un agent qui doit céder la place à un autre déclare des `excludes:` (par exemple `performance` s'efface devant `system-monitor` quand on parle de « mon PC »).

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
