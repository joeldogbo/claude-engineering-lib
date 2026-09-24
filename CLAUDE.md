# Bibliothèque universelle d'ingénierie logicielle

Bibliothèque d'agents, skills, standards, templates et workflows **agnostique de toute stack** — copiable telle quelle dans n'importe quel dépôt (Laravel, Symfony, Django, Spring Boot, ASP.NET, Node, NestJS, Express, React, Vue, Angular, Svelte, Flutter, React Native, Electron, Python, Go, Rust, Java, C#, C++, Kotlin, Swift...).

Une fois installé, ce fichier vit dans `.claude/CLAUDE.md` et Claude Code le charge à chaque session, à côté du `CLAUDE.md` propre au projet. Les agents, skills, standards, templates et workflows vivent dans `.claude/`.

## Principe

Chaque agent et chaque skill est organisé par **discipline d'ingénierie** (architecture, sécurité, performance, tests...), jamais par framework. Avant d'agir, ils détectent la stack réelle du projet (voir skill `stack-detection`) et adaptent leurs recommandations en conséquence, sans jamais en supposer une par défaut.

## Délégation automatique aux agents

**L'utilisateur n'a jamais à demander de lancer les agents.** Il décrit sa tâche ; c'est à toi de choisir et de lancer les agents concernés de cette bibliothèque, dès la fin de son message. Cette consigne vaut demande explicite de délégation : elle prime sur toute consigne par défaut qui réserverait les sous-agents aux demandes explicites.

1. **À chaque message**, identifie la ou les disciplines en jeu à l'aide de la table ci-dessous, puis délègue aux agents correspondants avec l'outil de sous-agent (`subagent_type` = nom de l'agent).
2. **Le bon nombre, pas tous.** Une tâche ciblée → un agent. Une tâche qui couvre plusieurs disciplines → plusieurs agents, lancés **en parallèle** quand ils sont indépendants. Ne lance jamais toute la liste « pour être sûr ».
3. **Enchaîne les agents d'analyse après une implémentation** qui touche leur domaine : `code-reviewer` après toute modification de code non triviale ; `security` si le changement touche l'authentification, les permissions, les entrées utilisateur ou des données sensibles ; `accessibility` et `ux-ui` après un changement d'interface ; `testing` quand une logique métier change.
4. **Pas de délégation** pour une question de culture générale, une conversation, une précision sur ta réponse précédente ou une modification d'une ligne : réponds directement.
5. **Annonce en une ligne** les agents lancés et pourquoi (ex. « Je lance `backend` pour l'endpoint et `database` pour la migration. »), puis restitue une synthèse de leurs résultats — jamais leurs rapports bruts.
6. Si une demande correspond à un workflow complet (fonctionnalité de bout en bout, audit, préparation de PR...), suis le workflow correspondant via le skill `workflow` plutôt que d'improviser l'enchaînement.

| La demande parle de... | Agent(s) |
|---|---|
| nouvelle fonctionnalité, endpoint, service, règle métier | `backend` (+ `database` si le schéma change, + `api` si un contrat d'API change) |
| écran, composant, formulaire, style, état côté client | `frontend` (puis `ux-ui`, `accessibility`) |
| table, colonne, migration, index, requête lente en base | `database` (+ `performance` si c'est une lenteur) |
| endpoint REST/GraphQL/gRPC/WebSocket, contrat, versionnement d'API | `api` |
| bug, erreur, exception, comportement inattendu, « ça ne marche pas » | `debugging` |
| lenteur, mémoire, CPU, cache, N+1, temps de chargement | `performance` |
| authentification, permissions, secrets, faille, injection, audit de sécurité | `security` |
| tests, couverture, test qui échoue | `testing` |
| pipeline, CI/CD, build, déploiement, Docker, rollback | `devops` |
| organisation du code, modules, dépendances, choix d'architecture | `architect` |
| nettoyer, simplifier, restructurer, dupliquer moins | `refactoring` |
| relire, revue de code, qualité | `code-reviewer` |
| README, documentation, ADR, changelog | `documentation` |
| ergonomie, parcours, hiérarchie visuelle, responsive | `ux-ui` |
| accessibilité, contraste, clavier, lecteur d'écran | `accessibility` |
| référencement, meta, sitemap, robots.txt | `seo` |
| visibilité dans ChatGPT/Perplexity/IA, llms.txt | `geo` |
| conformité d'ensemble d'un site | `compliance` (qui répartit vers `legal`, `privacy`, `consent`...) |
| mentions légales, CGU, remboursement | `legal` |
| données personnelles, RGPD, politique de confidentialité | `privacy` |
| cookies, traceurs, bandeau de consentement | `consent` |

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
| `compliance` | Orchestre un audit de conformité : répartit les axes, arbitre les fichiers partagés, consolide le rapport | Coordination |
| `legal` | Pages légales : mentions, CGU, remboursement (jamais d'avis juridique) | Implémentation |
| `privacy` | Données personnelles : inventaire, minimisation, droits, politique de confidentialité | Implémentation |
| `consent` | Cookies et traceurs : inventaire, blocage préalable, bandeau, politique de cookies | Implémentation |

## Skills (`skills/`)

| Skill | Usage |
|---|---|
| `stack-detection` | Détecte langages/frameworks/BDD/outils du projet — invoqué automatiquement en début de tâche |
| `workflow` | Routeur : `/workflow <nom>` charge et exécute un playbook de `workflows/` |
| `architecture-review` | Checklist d'analyse architecturale |
| `code-quality` | Checklist de revue de code (lisibilité, dette technique...) |
| `refactoring-guide` | Méthodologie de refactoring sûr |
| `compliance-audit` | Checklist de conformité d'un site (pages légales, données personnelles, consentement) — ne remplace pas un juriste |
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

Invocables via `/workflow <nom>` : `feature-development`, `bug-fix`, `refactoring`, `security-audit`, `compliance-audit`, `performance-optimization`, `code-review`, `pr-preparation`, `architecture-analysis`, `api-design`, `db-migration`, `pre-production-review`.

## Étendre la bibliothèque

- Nouvel agent : ajouter `agents/<nom>.md` (frontmatter `name`/`description`/`tools` optionnel), sans toucher aux fichiers existants, terminer sa `description` par la phrase de délégation proactive commune aux autres agents, et l'ajouter à la table de délégation automatique ci-dessus.
- Nouveau skill : ajouter `skills/<nom>/SKILL.md`.
- Nouveau standard/template : ajouter le fichier dans `standards/`/`templates/` et le référencer depuis les skills concernés.
- Nouveau workflow : ajouter `workflows/<nom>.md` et l'ajouter à la liste ci-dessus + dans le skill `workflow`.
