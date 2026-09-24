---
name: stack-detection
description: Détecte les langages, frameworks, gestionnaires de paquets, bases de données et outils utilisés par le projet en inspectant les fichiers manifestes. Utiliser en début de tâche non triviale, quand la stack n'est pas encore claire, ou quand l'utilisateur demande "quelle techno est utilisée ici".
---

# Détection de stack

## Instructions

1. Chercher à la racine (et dans les sous-dossiers d'application le cas échéant) les fichiers manifestes suivants, et ne conclure que sur ceux réellement présents :
   - **JS/TS** : `package.json` → lire `dependencies`/`devDependencies` pour identifier le framework (React, Vue, Angular, Svelte, Next.js, Nest.js, Express...) et le gestionnaire de paquets (`package-lock.json` → npm, `yarn.lock` → Yarn, `pnpm-lock.yaml` → pnpm).
   - **PHP** : `composer.json` (Laravel si `laravel/framework`, Symfony si `symfony/framework-bundle`...).
   - **Python** : `pyproject.toml`, `requirements.txt`, `Pipfile` (Django, Flask, FastAPI...).
   - **Go** : `go.mod`.
   - **Rust** : `Cargo.toml`.
   - **Java/Kotlin** : `pom.xml` (Maven) ou `build.gradle`/`build.gradle.kts` (Gradle) — Spring Boot si dépendance présente.
   - **.NET** : `*.csproj`/`*.sln`.
   - **Ruby** : `Gemfile`.
   - **Mobile/desktop** : `pubspec.yaml` (Flutter), config Xcode/Gradle (React Native, natif), config Electron dans `package.json`.
   - **Base de données** : rechercher dans les dépendances/config (`.env.example`, `docker-compose.yml`, config ORM) le driver utilisé (PostgreSQL, MySQL, SQLite, MongoDB, Redis...).
   - **Tests/CI** : dossier `tests/`/`spec/`, fichiers `.github/workflows/`, `.gitlab-ci.yml`, `Jenkinsfile`.

2. Produire une synthèse courte : langage(s) principal(aux), framework(s), gestionnaire de paquets, base(s) de données, outils de test et de CI détectés.

3. Ne jamais supposer une techno absente du projet. Si plusieurs langages/frameworks coexistent (monorepo), le préciser plutôt que de n'en retenir qu'un.

4. Utiliser cette synthèse pour orienter le choix des standards (`.claude/standards/`) et des agents/skills pertinents pour la suite de la tâche.
