---
name: documentation-standards
description: Maintien de la documentation — README, Architecture Decision Records, documentation technique et utilisateur, changelog. Utiliser quand un changement affecte un comportement documenté, ou quand l'utilisateur demande de documenter quelque chose.
---

# Standards de documentation

## Instructions

1. **README** : garder synchronisé avec la réalité (installation, commandes, prérequis) — une instruction obsolète est pire qu'une absence d'instruction.
2. **ADR** : utiliser le gabarit [adr.md](../../templates/adr.md) pour toute décision architecturale significative et difficile à revenir en arrière (voir workflow `architecture-analysis`).
3. **Documentation technique** : expliquer le "pourquoi" des choix non évidents, pas reformuler ce que le code montre déjà.
4. **Documentation utilisateur** : rédigée du point de vue de celui qui utilise la fonctionnalité, pas du point de vue de l'implémentation interne.
5. **Changelog** : une entrée par changement visible, avec le gabarit [entree-changelog.md](../../templates/entree-changelog.md), alignée sur [semver-conventional-commits.md](../../standards/semver-conventional-commits.md).

## Règle

Documenter ce qui ne se déduit pas facilement du code (intentions, contraintes, décisions). Ne pas dupliquer dans la doc ce qu'un nommage clair rend déjà évident.
