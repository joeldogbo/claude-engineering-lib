---
name: database-design
description: Analyse et conception de schéma de base de données — structure, index, normalisation, contraintes, intégrité, transactions, verrouillage, migrations. Utiliser pour concevoir un schéma, revoir des migrations, ou diagnostiquer un problème de données, sans supposer de SGBD particulier.
---

# Conception de base de données

## Instructions

1. **Détecter le SGBD réel** utilisé (skill `stack-detection`) avant toute recommandation spécifique (les contraintes diffèrent entre relationnel et NoSQL, entre PostgreSQL/MySQL/SQLite...).
2. **Structure** : les tables/collections reflètent-elles fidèlement le domaine métier ? Éviter la sur-normalisation qui multiplie les jointures sans bénéfice réel, et la sous-normalisation qui duplique une donnée qui devrait avoir une seule source de vérité.
3. **Contraintes d'intégrité** : clés étrangères, unicité, nullabilité cohérentes avec les règles métier réelles (pas seulement validées côté application).
4. **Index** : présents sur les colonnes filtrées/jointes fréquemment ; absents sur les colonnes peu sélectives ou rarement interrogées (un index inutile coûte en écriture).
5. **Transactions** : les opérations qui doivent être atomiques le sont-elles réellement ? Niveau d'isolation adapté au besoin (éviter les lectures sales, éviter aussi un niveau trop strict qui cause des verrous inutiles).
6. **Migrations** : réversibles quand possible, sûres sur un volume de données de production (voir workflow `db-migration` pour le risque de verrouillage sur une table volumineuse).

## Restitution

Constats priorisés avec justification (quel scénario réel serait affecté), adaptés au SGBD réellement détecté.
