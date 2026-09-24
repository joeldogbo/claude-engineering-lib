---
name: architecture-review
description: Analyse l'architecture globale d'un projet ou d'un module (découpage, responsabilités, dépendances, évolutivité, maintenabilité). Utiliser pour une revue d'architecture, avant une décision structurante, ou quand l'utilisateur demande un avis sur l'organisation du code.
---

# Revue d'architecture

## Instructions

Analyser, en s'appuyant sur [SOLID](../../standards/solid.md), [Clean Architecture / Hexagonale](../../standards/clean-architecture-hexagonale.md) et [DDD/CQRS](../../standards/ddd-cqrs.md) si pertinent :

1. **Découpage des modules** : les responsabilités sont-elles clairement séparées ? Un module a-t-il une seule raison de changer ?
2. **Dépendances** : y a-t-il des dépendances circulaires ? Le métier dépend-il directement d'un détail technique (framework, ORM, driver HTTP) au lieu d'une abstraction ?
3. **Extensibilité** : ajouter une variante (nouveau type, nouveau canal, nouvelle règle) nécessite-t-il de modifier du code existant qui fonctionne, ou peut-on étendre proprement ?
4. **Cohérence du modèle de données** avec le domaine métier réel.
5. **Points de couplage fort** qui rendraient une évolution future coûteuse (fichier "dieu", classe que tout le monde importe).

## Restitution

Constats priorisés par impact × coût de correction, avec fichier/module concerné. Ne pas recommander un changement structurant pour un problème dont le coût réel est faible (voir [dry-kiss-yagni.md](../../standards/dry-kiss-yagni.md)).
