---
name: library-update
description: Met à jour la bibliothèque d'agents installée dans `.claude/` (agents, skills, standards, templates, workflows, régulateur) sans perdre les modifications locales — simulation, application après accord, puis fusion des fichiers en conflit (`.claude/updates/*.new`). Utiliser quand l'utilisateur demande de mettre à jour, faire évoluer ou réinstaller les agents de la bibliothèque.
argument-hint: [version, ex. v1.4.0 — dernière release par défaut]
---

# Mise à jour de la bibliothèque

La mise à jour passe toujours par l'installateur, qui compare chaque fichier à l'empreinte notée dans `.claude/.claude-lib.manifest` lors de l'installation précédente. Ne copie jamais de fichiers à la main par-dessus `.claude/` : le manifeste ne serait plus à jour et les modifications locales seraient perdues sans sauvegarde.

## Ce que l'installateur fait de chaque fichier

| Situation | Résultat |
|---|---|
| Inchangé chez l'utilisateur, nouvelle version dans la bibliothèque | Remplacé ; ancienne version dans `.claude/backups/<date>/` |
| Modifié chez l'utilisateur, inchangé dans la bibliothèque | Conservé |
| Modifié des deux côtés (conflit) | Conservé ; nouvelle version dans `.claude/updates/<fichier>.new` |
| Retiré de la bibliothèque | Supprimé (sauvegardé) s'il n'a pas été modifié, conservé sinon |
| Agent supprimé par l'utilisateur | Pas réinstallé, sauf demande explicite (`--agents <nom>`) |
| Nouvel agent d'un groupe installé | Ajouté |
| Fichier propre à l'utilisateur (absent de la bibliothèque) | Jamais touché |
| Version demandée plus ancienne que celle installée | Refusé, sauf `--force` |
| Installation antérieure au manifeste | Fichiers différents remplacés après sauvegarde, sauf `CLAUDE.md` (traité en conflit) |

Une erreur ou une interruption en cours d'écriture restaure l'état d'avant ; une seule installation peut tourner à la fois dans un projet (verrou `.claude/.claude-lib.lock`).

## Étapes

1. **Prérequis.** Vérifie que `.claude/.claude-lib.manifest` ou `.claude/hooks/regulator.*` existe ; sinon, il n'y a rien à mettre à jour : propose l'installation (README). Repère le shell : `bash` (Linux, macOS, WSL, Git Bash) ou PowerShell (Windows). Version visée : `$ARGUMENTS` si fourni, sinon la dernière release.
2. **Simulation**, sans rien écrire :
   - bash : `curl -fsSL https://raw.githubusercontent.com/joeldogbo/claude-engineering-lib/main/install.sh | bash -s -- --update --dry-run [--version <v>]`
   - PowerShell : `$env:CLAUDE_LIB_UPDATE=1; $env:CLAUDE_LIB_DRY_RUN=1; iwr -useb https://raw.githubusercontent.com/joeldogbo/claude-engineering-lib/main/install.ps1 | iex` (puis retirer ces deux variables) ; avec une version précise : `& ([scriptblock]::Create((iwr -useb .../install.ps1))) -Update -DryRun -Version <v>`.

   Résume le plan à l'utilisateur : ajoutés, mis à jour, conflits (`!`), supprimés, conservés.
3. **Accord**, puis application : la même commande sans `--dry-run` / `-DryRun`. Ne propose `--force` / `-Force` que si l'utilisateur veut abandonner ses modifications locales, en rappelant qu'elles seront sauvegardées dans `.claude/backups/`.
4. **Fusion des conflits.** Pour chaque `.claude/updates/<fichier>.new` :
   - compare-le au fichier en place et à l'ancienne version de la bibliothèque si elle est disponible (dernière sauvegarde, ou dépôt de la bibliothèque à la version précédente indiquée par le manifeste) pour isoler ce que l'utilisateur a changé ;
   - reporte les changements de l'utilisateur sur la nouvelle version (pas l'inverse) ; pour un agent, garde toujours le frontmatter de la nouvelle version (`name`, `triggers`, `group`, `after`) et ajoute les déclencheurs propres à l'utilisateur ;
   - en cas de doute sur une règle contradictoire, demande à l'utilisateur au lieu de trancher ;
   - une fois le fichier fusionné, supprime le `.new` correspondant. Le manifeste garde l'empreinte de l'ancienne version : le fichier restera vu comme « modifié chez toi » et ne sera jamais écrasé silencieusement.
5. **Contrôle.** Lance l'audit du régulateur (`bash .claude/hooks/regulator.sh --audit` ou `.claude/hooks/regulator.ps1 -Audit`) s'il est disponible, et signale tout agent en échec.
6. **Fin.** Rappelle de **redémarrer la session Claude Code** : les agents ne sont chargés qu'au démarrage. Indique où sont les sauvegardes.

## En cas d'erreur

Lis le message `ERREUR` de l'installateur : il dit la cause et rien n'a été modifié (restauration automatique). Cas fréquents :
- « Une autre installation est en cours » : vérifie qu'aucun installateur ne tourne, puis seulement supprime `.claude/.claude-lib.lock` avec l'accord de l'utilisateur ;
- « plus récente que » : la version demandée est antérieure ; ne passe `--force` qu'avec l'accord explicite de l'utilisateur ;
- téléchargement impossible : une nouvelle tentative, puis indique le problème réseau ou proxy sans boucler.

Applique la gestion des erreurs du [protocole commun des agents](../../standards/agent-protocol.md#5-gestion-des-erreurs).
