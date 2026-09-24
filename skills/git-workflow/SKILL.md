---
name: git-workflow
description: Bonnes pratiques Git — qualité des commits, stratégie de branches, Conventional Commits, historique propre. Utiliser avant de committer, quand l'utilisateur demande un avis sur son historique Git, ou pour définir une stratégie de branches.
---

# Workflow Git

## Instructions

1. **Commits** : suivre [semver-conventional-commits.md](../../standards/semver-conventional-commits.md) et le gabarit [message-commit.md](../../templates/message-commit.md) — un commit = un changement logique cohérent, message au présent décrivant le "pourquoi".
2. **Branches** : nommer selon la convention déjà utilisée dans le projet (ex. `feature/...`, `fix/...`) ; une branche = un sujet, pas plusieurs mélangés.
3. **Historique** : préférer des commits atomiques et compréhensibles individuellement plutôt qu'un unique gros commit ; éviter les commits "wip"/"fix typo" dans l'historique final si l'équipe garde un historique propre (squash avant merge si c'est la convention du projet).
4. **Actions à risque** : ne jamais utiliser de commande destructive (`push --force` sur une branche partagée, `reset --hard`, suppression de branche) sans confirmation explicite — voir les règles de prudence générales.
5. **Avant de committer** : vérifier `git status`/`git diff` pour s'assurer qu'aucun fichier indésirable (secret, fichier temporaire) n'est inclus.

## Restitution

Si revue d'un historique existant : signaler les commits qui mélangent plusieurs sujets ou dont le message ne reflète pas le changement réel, avec suggestion de message correct.
