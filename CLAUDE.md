# Bibliothèque universelle d'ingénierie logicielle

Bibliothèque d'agents, skills, standards, templates et workflows **agnostique de toute stack** — copiable telle quelle dans n'importe quel dépôt (Laravel, Symfony, Django, Spring Boot, ASP.NET, Node, NestJS, Express, React, Vue, Angular, Svelte, Flutter, React Native, Electron, Python, Go, Rust, Java, C#, C++, Kotlin, Swift...).

Ce fichier est un index de référence humain (non auto-chargé par Claude Code). Les instructions réellement chargées à chaque session sont dans le `CLAUDE.md` à la racine du dépôt.

## Principe

Chaque agent et chaque skill est organisé par **discipline d'ingénierie** (architecture, sécurité, performance, tests...), jamais par framework. Avant d'agir, ils détectent la stack réelle du projet (voir skill `stack-detection`) et adaptent leurs recommandations en conséquence, sans jamais en supposer une par défaut.

## Agents (`agents/`)

| Agent | Rôle | Mode |
|---|---|---|
| `architect` | Architecture globale, découpage modules, dépendances, évolutivité | Analyse seule |
| `backend` | Logique métier, services, couche domaine côté serveur | Implémentation |
| `frontend` | UI, composants, état, interactions client | Implémentation |
| `database` | Schéma, index, contraintes, migrations, intégrité | Implémentation |
| `security` | Auth, autorisation, secrets, OWASP, injections | Analyse seule |
| `performance` | CPU, mémoire, cache, requêtes N+1, pagination | Analyse seule |
| `devops` | Pipelines CI/CD, build, déploiement, rollback | Implémentation |
| `testing` | Stratégie de tests unitaires/intégration/E2E | Implémentation |
| `ux-ui` | Ergonomie, hiérarchie visuelle, cohérence graphique | Analyse seule |
| `accessibility` | Accessibilité (a11y), contraste, navigation clavier | Analyse seule |
| `documentation` | README, ADR, doc technique/utilisateur, changelog | Implémentation |
| `code-reviewer` | Lisibilité, duplication, complexité, conventions | Analyse seule |
| `refactoring` | Simplification, extraction, suppression de duplication | Implémentation |
| `api` | Conception REST/GraphQL/gRPC/WebSocket | Implémentation |
| `debugging` | Méthodologie de reproduction/isolation/correction de bug | Implémentation |
| `seo` | Référencement naturel : meta, données structurées, sitemap, robots.txt | Implémentation |
| `geo` | Optimisation pour moteurs génératifs/IA : citabilité, llms.txt | Implémentation |

## Skills (`skills/`)

| Skill | Usage |
|---|---|
| `stack-detection` | Détecte langages/frameworks/BDD/outils du projet — invoqué automatiquement en début de tâche |
| `workflow` | Routeur : `/workflow <nom>` charge et exécute un playbook de `workflows/` |
| `architecture-review` | Checklist d'analyse architecturale |
| `code-quality` | Checklist de revue de code (lisibilité, dette technique...) |
| `refactoring-guide` | Méthodologie de refactoring sûr |
| `performance-audit` | Checklist de performance (CPU, mémoire, réseau, cache) |
| `security-audit` | Checklist de sécurité (OWASP, auth, secrets) |
| `database-design` | Checklist de conception BDD (index, normalisation, transactions) |
| `api-design` | Bonnes pratiques REST/GraphQL/gRPC/WebSocket |
| `ui-ux-review` | Checklist ergonomie/accessibilité/responsive |
| `test-strategy` | Stratégie de couverture de tests, sans imposer de framework |
| `documentation-standards` | Maintien README/ADR/changelog |
| `git-workflow` | Qualité des commits, stratégie de branches |
| `cicd-pipeline` | Bonnes pratiques pipeline CI/CD |
| `debugging-methodology` | Méthodologie de reproduction → isolation → correction |
| `optimization-guide` | Recherche de gains de perf/simplification/architecture |

## Standards (`standards/`)

Fiches de référence condensées, lues à la demande par les agents/skills : `solid.md`, `dry-kiss-yagni.md`, `clean-code.md`, `clean-architecture-hexagonale.md`, `ddd-cqrs.md`, `owasp-top10.md`, `rest-api-design.md`, `semver-conventional-commits.md`, `psr-php.md` (appliqué seulement si PHP est détecté).

## Templates (`templates/`)

`pr-description.md`, `message-commit.md`, `adr.md`, `rapport-bug.md`, `entree-changelog.md`.

## Workflows (`workflows/`)

Invocables via `/workflow <nom>` : `feature-development`, `bug-fix`, `refactoring`, `security-audit`, `performance-optimization`, `code-review`, `pr-preparation`, `architecture-analysis`, `api-design`, `db-migration`, `pre-production-review`.

## Étendre la bibliothèque

- Nouvel agent : ajouter `agents/<nom>.md` (frontmatter `name`/`description`/`tools` optionnel), sans toucher aux fichiers existants.
- Nouveau skill : ajouter `skills/<nom>/SKILL.md`.
- Nouveau standard/template : ajouter le fichier dans `standards/`/`templates/` et le référencer depuis les skills concernés.
- Nouveau workflow : ajouter `workflows/<nom>.md` et l'ajouter à la liste ci-dessus + dans le skill `workflow`.
