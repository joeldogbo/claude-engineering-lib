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

49 agents, 24 skills, 13 standards de référence (dont le [protocole commun des agents](standards/agent-protocol.md)), 7 templates et 16 workflows invocables via `/workflow <nom>`. Ces index vivent ici plutôt que dans `CLAUDE.md`, relu à chaque session : Claude Code charge déjà la description de chaque agent et de chaque skill.

### Agents

Tu n'as pas à les appeler : décris ta tâche, le [régulateur](#le-régulateur) choisit les bons agents. Tu peux aussi en nommer un (« utilise l'agent `seo` »).

**Trois façons de travailler :**
- 🔍 **Analyse** : il lit le projet et te remet un rapport, sans rien modifier.
- 🛠️ **Action** : il modifie le code ou les fichiers.
- 🧭 **Coordination** : il organise le travail des autres agents.

Un agent d'analyse est souvent suivi de son agent d'action : `security` trouve les failles, puis `security-fixer` les corrige.

Les agents sont rangés par **groupe d'installation** (`--groups <nom>`). Le groupe `core` est toujours installé.

#### `core` — le socle

| Agent | En clair | Mode | Exemple de demande |
|---|---|---|---|
| `project-context` | Tient la mémoire commune du projet pour que les agents partagent les mêmes infos | 🧭 | *(automatique)* |
| `request-history` | Vérifie si une demande a déjà été traitée, pour ne refaire que ce qui manque | 🔍 | *(automatique)* |
| `language` | Fixe la langue du projet (docs, interface, commits) et gère les traductions | 🛠️ | « Traduis l'interface en anglais » |
| `specifications` | Rédige le cahier des charges : objectifs, user stories, critères d'acceptation | 🛠️ | « Écris le cahier des charges de mon appli de réservation » |
| `architect` | Juge l'organisation du code : modules, dépendances, évolutivité | 🔍 | « Mon projet est-il bien structuré ? » |
| `code-reviewer` | Relit le code : lisibilité, duplication, complexité | 🔍 | « Relis mes dernières modifications » |
| `refactoring` | Simplifie et nettoie le code sans changer son comportement | 🛠️ | « Ce fichier fait 800 lignes, découpe-le » |
| `testing` | Écrit les tests unitaires, d'intégration et de bout en bout | 🛠️ | « Ajoute des tests sur le panier » |
| `debugging` | Reproduit un bug, trouve sa cause et le corrige | 🛠️ | « Erreur 500 sur /api/orders » |
| `git` | Fait des commits propres et pousse après ton accord | 🛠️ | « Commit et push » |
| `versioning` | Calcule le numéro de version et le met à jour partout | 🛠️ | « Prépare la version suivante » |
| `reverse-engineering` | Étudie une fonctionnalité d'une appli existante pour la refaire en mieux, sans la copier | 🔍 | « Je veux la même recherche que sur Airbnb » |

#### `docs` — documentation

| Agent | En clair | Mode | Exemple de demande |
|---|---|---|---|
| `documentation` | README, changelog, décisions d'architecture (ADR) | 🛠️ | « Mets le README à jour » |
| `manuals` | Manuels développeur, utilisateur et de déploiement, écrits d'après le vrai code | 🛠️ | « Rédige le manuel utilisateur » |
| `knowledge-base` | Carte du code : qui appelle quoi, impact d'un changement | 🛠️ | « Que casse-t-on si on modifie User ? » |

#### `ui` — interface

| Agent | En clair | Mode | Exemple de demande |
|---|---|---|---|
| `art-director` | Définit l'identité visuelle et la structure d'une page **avant le code**, pour éviter les interfaces génériques « faites par IA » | 🔍 | « Crée la landing page de mon salon, sans AI slop » |
| `frontend` | Code l'interface : composants, écrans, formulaires, interactions | 🛠️ | « Ajoute un écran de profil » |
| `framework-expert` | Utilise ton framework (React, Flutter, Laravel...) comme le recommande sa documentation officielle | 🛠️ | « Est-ce la bonne façon de faire en Next.js ? » |
| `ux-ui` | Vérifie l'ergonomie et le visuel : espacements, typographie, rendu mobile et desktop | 🔍 | « Mon interface est-elle bien faite ? » |
| `accessibility` | Vérifie que tout le monde peut utiliser l'interface : contrastes, clavier, lecteurs d'écran | 🔍 | « Mon site est-il accessible ? » |
| `multimedia` | Images, vidéos et audio : formats, poids, chargement, téléversements | 🛠️ | « Mes images sont trop lourdes » |

#### `backend` — serveur

| Agent | En clair | Mode | Exemple de demande |
|---|---|---|---|
| `backend` | Code la logique métier côté serveur | 🛠️ | « Calcule les frais de livraison » |
| `api` | Conçoit les API (REST, GraphQL, WebSocket...) | 🛠️ | « Crée l'API des commandes » |
| `api-resilience` | Rend une API robuste : validation, erreurs, délais, nouvelles tentatives | 🛠️ | « Mon API plante quand le paiement est lent » |
| `database` | Schéma, index, migrations, intégrité des données | 🛠️ | « Ajoute une table des factures » |
| `database-builder` | Crée une base complète d'un coup : schéma, migrations, données de test | 🛠️ | « Crée la base de mon appli de cours » |
| `integrations` | Connecte des services externes et fait tourner les tâches planifiées | 🛠️ | « Synchronise les inscrits avec Moodle » |
| `emails` | E-mails automatiques : bienvenue, reçus, rappels | 🛠️ | « Envoie un reçu après chaque achat » |

#### `security` — sécurité

| Agent | En clair | Mode | Exemple de demande |
|---|---|---|---|
| `security` | Cherche les failles et donne une note de sécurité sur 100 | 🔍 | « Audite la sécurité du projet » |
| `security-fixer` | Corrige les failles trouvées, une par une, avec un test pour chacune | 🛠️ | « Corrige les failles de l'audit » |

#### `performance` — performance

| Agent | En clair | Mode | Exemple de demande |
|---|---|---|---|
| `performance` | Trouve ce qui ralentit l'application : requêtes, mémoire, cache | 🔍 | « La page des commandes est lente » |
| `load-testing` | Mesure combien d'utilisateurs l'application supporte avant de céder | 🛠️ | « Tiendra-t-on 1 000 visiteurs simultanés ? » |

#### `ops` — mise en production

| Agent | En clair | Mode | Exemple de demande |
|---|---|---|---|
| `deployment-advisor` | Conseille l'hébergement, les coûts et la mise en ligne | 🔍 | « Où héberger mon site ? » |
| `devops` | Met en place la CI/CD, le build et le déploiement | 🛠️ | « Déploie automatiquement à chaque push » |
| `dependencies` | Met à jour les dépendances obsolètes ou vulnérables | 🛠️ | « Mes paquets sont-ils à jour ? » |
| `incident-response` | Gère une panne en production, de la stabilisation au compte rendu | 🛠️ | « Le site est tombé ! » |

#### `seo` — visibilité web

| Agent | En clair | Mode | Exemple de demande |
|---|---|---|---|
| `seo` | Référencement Google : balises, sitemap, données structurées | 🛠️ | « Améliore le SEO de mon site » |
| `geo` | Visibilité dans les IA (ChatGPT, Perplexity...) : contenu citable, `llms.txt` | 🛠️ | « Fais en sorte que les IA citent mon site » |

#### `compliance` — conformité

| Agent | En clair | Mode | Exemple de demande |
|---|---|---|---|
| `compliance` | Orchestre un audit de conformité complet et en fait la synthèse | 🧭 | « Mon site est-il conforme ? » |
| `legal` | Pages légales : mentions, CGU, remboursement (pas un avis juridique) | 🛠️ | « Rédige mes CGU » |
| `privacy` | Données personnelles : ce qui est collecté, droits, politique de confidentialité | 🛠️ | « Suis-je conforme au RGPD ? » |
| `consent` | Cookies et traceurs : bandeau, blocage avant accord, politique de cookies | 🛠️ | « Ajoute un bandeau cookies » |
| `financial-compliance` | Repère les promesses de gains ou conseils financiers risqués (pas un avis juridique) | 🔍 | « Mes textes sur l'investissement sont-ils risqués ? » |

#### `business` — métier en ligne

| Agent | En clair | Mode | Exemple de demande |
|---|---|---|---|
| `payments` | Paiements de bout en bout : webhooks, remboursements, abonnements | 🛠️ | « Le client a payé mais n'a pas accès » |
| `ai-chatbot` | Chatbot IA : consignes, garde-fous, réponses fiables | 🛠️ | « Mon chatbot invente des réponses » |

#### `tooling` — outils du poste

| Agent | En clair | Mode | Exemple de demande |
|---|---|---|---|
| `token-monitor` | Montre ce que Claude Code consomme en jetons et comment réduire | 🔍 | « Combien de jetons cette semaine ? » |
| `prompt-compressor` | Raccourcit les prompts relus à chaque session sans perdre de règle | 🛠️ | « Mes prompts gaspillent des jetons » |
| `system-monitor` | Diagnostique un PC lent : processeur, mémoire, disque, batterie | 🔍 | « Mon PC est très lent » |
| `mcp-developer` | Crée des serveurs MCP pour donner de nouveaux outils à Claude | 🛠️ | « Crée un serveur MCP pour mon API » |

### Skills

| Skill | Usage |
|---|---|
| `stack-detection` | Détecte langages/frameworks/BDD/outils du projet — invoqué automatiquement en début de tâche |
| `workflow` | Routeur : `/workflow <nom>` charge et exécute un playbook de `workflows/` |
| `architecture-review` | Checklist d'analyse architecturale |
| `code-quality` | Checklist de revue de code (lisibilité, dette technique...) |
| `refactoring-guide` | Méthodologie de refactoring sûr |
| `compliance-audit` | Checklist de conformité d'un site (pages légales, données personnelles, consentement) — ne remplace pas un juriste |
| `performance-audit` | Checklist de performance (CPU, mémoire, réseau, cache) |
| `security-audit` | Audit de sécurité en 6 phases : scan local, CVE via OSV, revue OWASP Web + API, score /100, rapport avec correctifs |
| `database-design` | Checklist de conception BDD (index, normalisation, transactions) |
| `hierarchical-data` | Données en arbre : liste d'adjacence, représentation intervallaire, table de clôture, chemin matérialisé — choix du modèle, requêtes vérifiées par un script, intégrité, cas de test |
| `api-design` | Bonnes pratiques REST/GraphQL/gRPC/WebSocket |
| `ui-ux-review` | Revue UI/UX complète : espacements, typographie, responsive, couleur, états, références externes |
| `test-strategy` | Stratégie de couverture de tests, sans imposer de framework |
| `documentation-standards` | Maintien README/ADR/changelog |
| `git-workflow` | Qualité des commits, stratégie de branches |
| `cicd-pipeline` | Bonnes pratiques pipeline CI/CD |
| `debugging-methodology` | Méthodologie de reproduction → isolation → correction |
| `optimization-guide` | Recherche de gains de perf/simplification/architecture |
| `prompt-writer` | `/prompt-writer <brouillon>` : réécrit une demande en prompt clair (objectif, périmètre, résultat attendu) avant de l'exécuter — invoqué uniquement par l'utilisateur |
| `token-usage` | `/token-usage [jours]` : script qui résume la consommation de jetons de Claude Code sans lire le contenu des conversations |
| `system-health` | `/system-health` : script de diagnostic du poste en lecture seule (Windows, macOS, Linux) |
| `reverse-engineering` | Méthode de rétro-ingénierie fonctionnelle (inspirée de REA) : questions, sources de preuve par type de cible, registre des preuves, amélioration, vérification de la reconstruction |
| `library-update` | `/library-update [version]` : met à jour la bibliothèque installée (simulation, application après accord, fusion des fichiers modifiés localement) |
| `agents-status` | Mod (pas un skill) chargé automatiquement : affiche sous la zone de saisie les agents retenus par le régulateur et ceux au travail, et renomme la ligne d'activité (« Agent backend au travail… ») |

## Utilisation

Une fois installée dans un projet, la bibliothèque est chargée automatiquement par Claude Code via `.claude/CLAUDE.md`. **Décris simplement ta tâche** : à la fin de ton message, Claude choisit et lance lui-même les agents concernés (par exemple `backend` + `database` pour une nouvelle fonctionnalité avec migration, puis `code-reviewer` et `security` sur le résultat). Inutile d'écrire « lance les agents ».

### Le régulateur

Avec des dizaines d'agents, les laisser chacun décider de se lancer mènerait au désordre. Un seul contrôleur décide donc : le **régulateur**, un hook Claude Code (`.claude/hooks/regulator.sh`, ou `regulator.ps1` sous Windows) que l'installateur enregistre dans `.claude/settings.json`.

- **Obligatoire et automatique** : il s'exécute sur chaque prompt, avant que Claude le lise, et ne consomme aucun jeton de modèle.
- **Il tranche** : il compare le message au champ `triggers:` de chaque agent et ajoute au contexte la liste des agents retenus (quatre au plus), ou « aucun agent ». Claude ne lance que ceux-là.
- **Il se met à jour seul** : il relit `.claude/agents/` à chaque prompt ; un nouvel agent doté d'un champ `triggers:` est pris en compte immédiatement.
- **Il se vérifie** : `bash .claude/hooks/regulator.sh --audit` échoue si un agent n'a pas de déclencheurs, de groupe, de lien vers le [protocole commun](standards/agent-protocol.md) ou de garde-fou, si un fichier contient des caractères invisibles, si `CLAUDE.md` dépasse 8 Ko ou une description d'agent 300 caractères (ce qui est relu à chaque session reste compressé : au-delà, passer par `prompt-compressor` avant de publier), ou si son `after:` vise un agent inexistant ; il signale aussi les déclencheurs partagés. La CI l'exécute à chaque modification d'agent : la règle vaut pour les anciens agents comme pour les nouveaux. Un agent qui doit céder la place à un autre déclare des `excludes:` (par exemple `performance` s'efface devant `system-monitor` quand on parle de « mon PC »).
- **Il enchaîne les niveaux N1 → N2** : un agent d'analyse (N1) relève, l'agent de correction associé (N2) corrige à partir de son rapport, puis le N1 revérifie — `security` → `security-fixer`, `code-reviewer` et `architect` → `refactoring`, `ux-ui` et `accessibility` → `frontend`, `deployment-advisor` → `devops`. Le régulateur affiche la chaîne pour que Claude les lance l'un après l'autre, jamais en parallèle.
- **Il reprend le travail interrompu** : pour une tâche de plusieurs étapes, l'agent tient un point de reprise dans `.claude/progress/<sujet>.md` et coche chaque étape terminée. Après une coupure de connexion ou une session fermée, le régulateur le signale au message suivant et Claude reprend à la première étape non cochée, sans refaire le reste. Ces fichiers sont locaux : ajoute `.claude/progress/` au `.gitignore` du projet si tu ne veux pas les versionner.
- **Il repère les demandes répétées** : chaque message est comparé aux 200 précédents du projet. S'il reprend au moins 75 % des mots d'un message déjà envoyé, le régulateur le signale avec sa date, et l'agent `request-history` vérifie ce qui est déjà fait (git, points de reprise, fichiers) avant de ne faire que ce qui manque. Le journal `.claude/hooks/prompts.log` reste local, est ignoré par git et ne garde que des mots normalisés, pas le texte des messages.
- **Il impose la langue du projet** : l'agent `language` inscrit dans `.claude/project-context.md` la langue de la documentation, de l'interface et des commits ; tous les agents l'appliquent.

### Voir les agents travailler

Le mod `agents-status` (`.claude/skills/agents-status/`), chargé automatiquement par Claude Code dans les sessions interactives, montre en permanence le travail des agents :

- **sous la zone de saisie**, la ligne d'état affiche `◆ Agents retenus : backend, api` après chaque message, puis `▶ Agents au travail : backend` tant qu'un agent tourne ;
- **dans la ligne d'activité animée**, le texte devient « Agent backend au travail… » ;
- **dans le fil de la conversation**, Claude annonce les agents lancés et chaque appel d'agent porte son nom (`backend : endpoint de présence`) ;
- **pour le régulateur** : tu peux écrire pendant que des agents travaillent. Juste avant le régulateur, le mod écrit la liste des agents encore au travail dans `.claude/hooks/agents.running` (ignoré par git), et le régulateur la signale. Si ton message concerne leur travail, Claude le leur transmet au lieu de lancer un second agent sur les mêmes fichiers : pas de modifications qui s'écrasent, pas de jetons dépensés en double.

Les agents, comme ce mod, ne sont chargés qu'**au démarrage d'une session** : après une installation, redémarre Claude Code (ou recharge la fenêtre VS Code). Le régulateur écrit sa sélection dans `.claude/hooks/regulator.last`, ignoré par git, que le mod relit.

### Économiser des jetons

La bibliothèque est conçue pour coûter peu à chaque session : `CLAUDE.md` court (environ 7 Ko), descriptions d'agents brèves, régulateur qui n'ajoute qu'une ligne par message. De ton côté :

- **Une demande précise** : fichiers concernés et résultat attendu dès le premier message. Pour un brouillon flou, `/prompt-writer <brouillon>` le transforme en prompt clair avant de l'exécuter.
- **L'extrait utile**, pas le journal entier : 30 lignes autour de l'erreur suffisent. Un message de plus de 20 000 caractères est bloqué par le régulateur **avant** d'atteindre le modèle, donc sans dépenser de jeton ; commence-le par `[long]` pour l'envoyer quand même. Le plafond se règle avec la variable d'environnement `REGULATOR_MAX_PROMPT` (`0` le désactive), par exemple dans le bloc `env` de `.claude/settings.json`.
- **Une session par sujet** : `/clear` entre deux tâches sans rapport, `/compact` quand une session s'allonge.
- **Mesurer** : `/token-usage` montre ce qui coûte le plus ; dis « mes prompts gaspillent des jetons » et l'agent `prompt-compressor` mesure le coût fixe, compresse ce qui peut l'être sans perdre de règle, et conseille.

Pour forcer un agent précis, nomme-le (« utilise l'agent `performance` »). Les workflows complets se lancent avec `/workflow <nom>`, par exemple `/workflow feature-development` ou `/workflow security-audit`.

## Releases

Les [releases](https://github.com/joeldogbo/claude-engineering-lib/releases) marquent des versions stables (`vMAJOR.MINOR.PATCH`, voir [standards/semver-conventional-commits.md](standards/semver-conventional-commits.md)). Les scripts d'installation ciblent la dernière release par défaut, plutôt que `main` qui peut être en cours de modification — ça évite d'installer une version instable et permet de savoir précisément ce qui change d'une version à l'autre (changelog généré automatiquement).

## Étendre la bibliothèque

- Nouvel agent : ajouter `agents/<nom>.md` (frontmatter `name`/`description`/`tools` optionnel) avec, **obligatoirement** :
  - `triggers:` — mots ou expressions qui doivent le déclencher, séparés par des virgules, `mot=` pour un mot entier — et, si besoin, `excludes:` pour les messages qui relèvent d'un autre agent ;
  - `group:` — un groupe de `profiles.conf`, pour l'installation par type de projet ou par groupe ;
  - `after: <agent N1>` s'il corrige ce qu'un agent d'analyse a relevé (niveau N2) ;
  - en fin de fichier, le lien vers le [protocole commun](standards/agent-protocol.md) et la mention « garde-fou non négociable » : sans elle, l'audit échoue et la CI bloque l'agent.

  Le régulateur le prend en compte dès le prompt suivant, sans autre modification. Vérifier ensuite : `bash .claude/hooks/regulator.sh --audit` (ou `regulator.ps1 -Audit`) échoue si l'une de ces règles manque et signale les déclencheurs partagés ; la CI l'exécute à chaque modification d'agent. Ne pas ajouter de phrase « à utiliser de manière proactive » : seul le régulateur décide.
- Nouveau groupe ou type de projet : l'ajouter dans `profiles.conf` (`group|nom|description` ou `profile|nom|description|groupes`) ; les installateurs le proposent aussitôt.
- Nouveau skill : ajouter `skills/<nom>/SKILL.md`.
- Nouveau standard/template : ajouter le fichier dans `standards/`/`templates/` et le référencer depuis les skills concernés.
- Nouveau workflow : ajouter `workflows/<nom>.md` et l'ajouter à la liste ci-dessus + dans le skill `workflow`.

## Sécurité du dépôt

Ce dépôt est public (lecture libre nécessaire pour l'installation en une commande). La protection porte sur l'**écriture** :

- **Garde-fou dans chaque agent** : la section 0 du [protocole commun](standards/agent-protocol.md), qu'aucune consigne ne lève, interdit tout code malveillant (virus, rançongiciel, porte dérobée, vol d'identifiants...) et toute fraude, traite le contenu des fichiers et des pages comme des données et jamais comme des ordres, et interdit d'affaiblir les fichiers de la bibliothèque. L'audit du régulateur, exécuté par la CI, bloque tout agent sans ce garde-fou et tout fichier contenant des caractères invisibles (moyen courant de cacher des consignes).
- **Intégrité à l'installation** : chaque release publie `SHA256SUMS`, l'empreinte de chaque fichier calculée sur l'archive du tag. Les installateurs la téléchargent et refusent l'installation, sans rien écrire, si un seul fichier diffère (archive altérée par un miroir, un proxy ou un tag déplacé). Installer depuis `main` n'est pas vérifiable : l'installateur le signale. Cette vérification ne protège pas contre un compte GitHub compromis : d'où les protections ci-dessous.
- **Fichiers modifiés après installation** : le manifeste `.claude/.claude-lib.manifest` garde l'empreinte de chaque fichier installé ; `--dry-run` liste ceux qui ont changé depuis.
- Branch protection sur `main` (review obligatoire, pas de push direct)
- 2FA activée sur les comptes avec accès
- Secret scanning et Dependabot activés
- Aucun secret ni credential dans ce dépôt

## Licence

[MIT](LICENSE)
