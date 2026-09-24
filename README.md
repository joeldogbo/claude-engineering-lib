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

Voir [CLAUDE.md](CLAUDE.md) pour l'index complet : 21 agents (architecture, backend, frontend, sécurité, performance, tests, devops, conformité...), 17 skills, 9 standards de référence, 5 templates et 14 workflows invocables via `/workflow <nom>`.

## Utilisation

Une fois installée dans un projet, la bibliothèque est chargée automatiquement par Claude Code via `.claude/CLAUDE.md`. **Décris simplement ta tâche** : à la fin de ton message, Claude choisit et lance lui-même les agents concernés (par exemple `backend` + `database` pour une nouvelle fonctionnalité avec migration, puis `code-reviewer` et `security` sur le résultat). Inutile d'écrire « lance les agents ».

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
