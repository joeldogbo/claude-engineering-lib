# Clean Architecture / Architecture Hexagonale

Deux formulations d'un même principe : isoler la logique métier des détails techniques (framework, BDD, UI, réseau).

## Idée centrale

Les dépendances pointent **vers l'intérieur**, du détail technique vers le métier — jamais l'inverse. Le cœur métier (domaine) ne connaît ni le framework web, ni le driver de base de données, ni le format de réponse HTTP.

## Couches typiques (Clean Architecture)

1. **Entités / domaine** : règles métier pures, aucune dépendance externe.
2. **Cas d'usage / application** : orchestration des règles métier pour un scénario donné.
3. **Interfaces (ports)** : contrats définis par le métier (ex. `UserRepository` en interface).
4. **Adaptateurs** : implémentations concrètes des ports (ORM, client HTTP, framework web) — c'est la couche qui dépend de la techno détectée.

## Architecture hexagonale (ports & adaptateurs)

Même logique, vocabulaire différent : le domaine expose des **ports** (interfaces), et chaque intégration externe (BDD, API tierce, UI, message queue) est un **adaptateur** qui implémente ou consomme ce port. Le domaine peut être testé sans aucune infrastructure réelle en substituant des adaptateurs de test.

## Signaux qu'elle est violée

- Une règle métier (calcul, validation critique) vit directement dans un contrôleur/handler HTTP ou dans une classe liée à l'ORM.
- Impossible de tester la logique métier sans démarrer une vraie base de données ou un vrai serveur HTTP.
- Changer de framework ou de BDD obligerait à réécrire la logique métier elle-même, pas seulement l'adaptateur.

## Quand l'appliquer

Pertinent dès que la logique métier a une complexité réelle ou une durée de vie longue. Sur un CRUD simple sans règle métier notable, cette séparation stricte peut être une sur-ingénierie (voir [dry-kiss-yagni.md](dry-kiss-yagni.md)) — un découpage plus léger en couches (contrôleur / service / accès aux données) suffit souvent.
