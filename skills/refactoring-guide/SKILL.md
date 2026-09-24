---
name: refactoring-guide
description: Méthodologie de refactoring sûr — simplification, extraction de méthode, suppression de duplication, amélioration des responsabilités, sans changer le comportement observable. Utiliser quand l'utilisateur demande de nettoyer, simplifier ou restructurer du code existant.
---

# Guide de refactoring

## Instructions

1. **Vérifier le filet de sécurité** : des tests couvrent-ils le comportement actuel ? Si non, en ajouter avant de toucher au code.
2. **Repérer les cibles** (voir [Clean Code](../../standards/clean-code.md), [SOLID](../../standards/solid.md)) :
   - Duplication de logique métier (pas de duplication accidentelle)
   - Fonction/classe avec plusieurs responsabilités mélangées
   - Nommage qui ne révèle plus l'intention réelle
   - Complexité conditionnelle qui pourrait être simplifiée (early return, extraction, polymorphisme)
3. **Refactorer par petites étapes** vérifiables indépendamment plutôt qu'un changement monolithique.
4. **Vérifier après chaque étape** que le comportement observable est identique (tests, pas seulement lecture visuelle).
5. **S'arrêter** quand le gain marginal d'une étape supplémentaire devient inférieur à son risque/coût — ne pas refactorer au-delà du besoin réel.

## Règle absolue

Un refactoring ne change jamais le comportement observable. Si un changement de comportement apparaît nécessaire en cours de route, le traiter comme un changement séparé (`feat`/`fix`), pas comme faisant partie du refactoring.
