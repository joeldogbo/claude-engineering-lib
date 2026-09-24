---
name: performance-audit
description: Analyse de performance — mémoire, CPU, temps d'exécution, cache, appels réseau, pagination, chargement eager/lazy, parallélisation. Utiliser quand l'utilisateur signale une lenteur, demande une optimisation, ou avant un audit de perf.
---

# Audit de performance

## Instructions

Analyser, sans supposer d'optimisation avant d'avoir identifié un goulot réel :

1. **Base de données** : requêtes N+1, index manquants sur les colonnes filtrées/jointes, transactions trop larges, chargement eager d'associations non utilisées (voir skill `database-design`).
2. **Cache** : absence de cache sur une donnée coûteuse et peu volatile, ou cache présent mais mal invalidé (données périmées servies).
3. **Réseau** : appels externes séquentiels qui pourraient être parallélisés, appels redondants pour la même donnée dans une même requête.
4. **Pagination** : collections potentiellement larges chargées en une fois sans limite.
5. **Chargement des données (eager/lazy)** : trop de données chargées d'un coup (sur-fetching) vs trop d'allers-retours (sous-fetching).
6. **CPU/mémoire** : boucles imbriquées sur de grandes collections, allocations répétées évitables, algorithmes en complexité non nécessaire pour le volume réel de données.

## Restitution

Constats priorisés par gain estimé × fréquence d'exécution du chemin concerné, avec fichier:ligne. Recommander de mesurer avant/après plutôt que d'affirmer un gain non vérifié. Ne pas sacrifier la lisibilité pour un gain marginal non mesuré (voir [dry-kiss-yagni.md](../../standards/dry-kiss-yagni.md)).
