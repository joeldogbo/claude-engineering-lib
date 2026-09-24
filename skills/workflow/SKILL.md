---
name: workflow
description: Exécute un processus d'ingénierie structuré et réutilisable (développement de fonctionnalité, correction de bug, refactoring, audit de sécurité, optimisation de performance, revue de code, préparation de PR, analyse d'architecture, création d'API, migration de base de données, revue pré-production). Utiliser quand l'utilisateur veut suivre un processus connu plutôt qu'improviser, ou invoquer directement avec /workflow <nom>.
argument-hint: [feature-development|bug-fix|refactoring|security-audit|performance-optimization|code-review|pr-preparation|architecture-analysis|api-design|db-migration|pre-production-review]
---

# Routeur de workflows

## Instructions

1. Déterminer quel workflow correspond à la demande parmi : `feature-development`, `bug-fix`, `refactoring`, `security-audit`, `performance-optimization`, `code-review`, `pr-preparation`, `architecture-analysis`, `api-design`, `db-migration`, `pre-production-review`.
   - Si `$ARGUMENTS` désigne déjà un nom valide, l'utiliser directement.
   - Sinon, déduire le workflow le plus pertinent du contexte de la conversation.
2. Lire le fichier correspondant dans `.claude/workflows/<nom>.md` (chemin relatif à la racine du projet).
3. Suivre les étapes de ce fichier, en déléguant aux agents et skills qu'il cite (`.claude/agents/`, `.claude/skills/`).
4. Si aucun workflow ne correspond clairement, le signaler plutôt que d'en forcer un qui ne convient pas, et proposer d'en discuter avec l'utilisateur.

Ne pas dupliquer le contenu des workflows ici : ce skill n'est qu'un point d'entrée qui charge et exécute le playbook approprié.
