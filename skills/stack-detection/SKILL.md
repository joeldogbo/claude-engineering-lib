---
name: stack-detection
description: Détecte les langages, frameworks, gestionnaires de paquets, bases de données et outils utilisés par le projet en inspectant les fichiers manifestes. Utiliser en début de tâche non triviale, quand la stack n'est pas encore claire, ou quand l'utilisateur demande "quelle techno est utilisée ici".
---

# Détection de stack

## Instructions

1. Chercher à la racine (et dans les sous-dossiers d'application le cas échéant) les fichiers manifestes suivants, et ne conclure que sur ceux réellement présents :
   - **JS/TS** : `package.json` → lire `dependencies`/`devDependencies` pour identifier le framework (React, Vue, Angular, Svelte/SvelteKit, Solid, Preact, Next.js, Nuxt, Remix, Astro, NestJS, Express, Fastify...) et le gestionnaire de paquets (`package-lock.json` → npm, `yarn.lock` → Yarn, `pnpm-lock.yaml` → pnpm, `bun.lockb` → Bun) ; `deno.json` → Deno.
   - **PHP** : `composer.json` (Laravel si `laravel/framework`, Symfony si `symfony/framework-bundle`...).
   - **Python** : `pyproject.toml`, `requirements.txt`, `Pipfile` (Django, Flask, FastAPI...).
   - **Ruby** : `Gemfile` (Rails si `rails`). **Elixir** : `mix.exs` (Phoenix si `phoenix`).
   - **Go** : `go.mod` (Gin, Echo, Fiber...). **Rust** : `Cargo.toml` (Axum, Actix, Rocket ; Tauri si `src-tauri/`).
   - **Java/Kotlin** : `pom.xml` (Maven) ou `build.gradle`/`build.gradle.kts` (Gradle) — Spring Boot, Ktor, JavaFX (`openjfx`) selon les dépendances.
   - **.NET** : `*.csproj`/`*.sln` — ASP.NET (`Microsoft.NET.Sdk.Web`, avec `Views/` ou `Pages/` pour MVC/Razor, `Components/` pour Blazor), WPF/WinForms (`<UseWPF>`, `<UseWindowsForms>`), .NET MAUI (`<UseMaui>`), Avalonia.
   - **C/C++** : `CMakeLists.txt`, `Makefile`, `meson.build` (Qt si `find_package(Qt...)`).
   - **Mobile** : `pubspec.yaml` (Flutter), React Native ou Expo, Ionic/Capacitor dans `package.json`, Android natif Kotlin/Java (`app/src/main/AndroidManifest.xml`), iOS natif Swift (`*.xcodeproj`, `Package.swift`).
   - **Bureau** : Electron ou Tauri (`package.json`, `src-tauri/`), WPF, WinForms, Avalonia, JavaFX, Qt.
   - **Base de données** : rechercher dans les dépendances/config (`.env.example`, `docker-compose.yml`, config ORM) le driver utilisé (PostgreSQL, MySQL, SQLite, MongoDB, Redis...).
   - **Tests/CI** : dossier `tests/`/`spec/`, fichiers `.github/workflows/`, `.gitlab-ci.yml`, `Jenkinsfile`.

2. Produire une synthèse courte : langage(s) principal(aux), framework(s), gestionnaire de paquets, base(s) de données, outils de test et de CI détectés, et **type de projet** (web, mobile, API, bureau, bibliothèque/CLI — les profils de `profiles.conf`). Relever aussi la langue humaine du projet si `.claude/project-context.md` ne l'indique pas encore (README, interface, `git log`) : elle s'impose à tous les agents (voir l'agent `language`).

3. Ne jamais supposer une techno absente du projet. Si plusieurs langages/frameworks coexistent (monorepo), le préciser plutôt que de n'en retenir qu'un.

4. Utiliser cette synthèse pour orienter le choix des standards (`.claude/standards/`) et des agents/skills pertinents pour la suite de la tâche.
