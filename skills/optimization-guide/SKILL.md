---
name: optimization-guide
description: Recherche transversale d'optimisations possibles — simplifications, gains de performance, améliorations d'architecture. Utiliser pour une passe d'optimisation générale qui ne se limite pas à un seul axe (perf pure, code, ou architecture).
---

# Guide d'optimisation transversale

## Instructions

Ce skill combine une vue d'ensemble ; pour un axe précis, préférer le skill dédié (`performance-audit`, `refactoring-guide`, `architecture-review`).

1. **Simplifications** : code plus complexe que nécessaire pour le problème réel (voir [dry-kiss-yagni.md](../../standards/dry-kiss-yagni.md)) — abstraction non justifiée, configuration non utilisée, couche intermédiaire sans valeur ajoutée.
2. **Performance** : voir skill `performance-audit` pour le détail (requêtes, cache, réseau, chargement des données).
3. **Architecture** : voir skill `architecture-review` pour le détail (découpage, dépendances, évolutivité).
4. **Priorisation** : classer chaque opportunité par rapport gain/effort réel, pas par facilité de mise en œuvre seule.

## Restitution

Une liste courte des opportunités à plus fort impact, chacune avec la mesure ou le raisonnement qui justifie le gain attendu — pas un audit exhaustif de tout ce qui pourrait théoriquement être amélioré.
