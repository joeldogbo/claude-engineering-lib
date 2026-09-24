# Workflow : Migration de base de données

1. **Détecter le SGBD et l'outil de migration** utilisés par le projet (fichiers de migration existants, ORM, outil dédié) — suivre exactement la convention déjà en place.
2. **Concevoir le changement** avec l'agent `database` + skill `database-design` :
   - Impact sur les contraintes existantes (clés étrangères, unicité, nullabilité)
   - Nécessité d'un backfill de données pour les lignes existantes
   - Index nécessaires pour les nouvelles requêtes prévues
3. **Évaluer le risque de verrouillage** : sur une table volumineuse en production, une migration bloquante (ex. `ALTER TABLE` qui verrouille toute la table) peut causer une interruption de service — vérifier si le SGBD/la version supporte une migration non bloquante, ou prévoir une fenêtre de maintenance.
4. **Écrire la migration** de façon réversible quand c'est possible (méthode de rollback), sauf si la nature du changement l'empêche (perte de données volontaire, à documenter explicitement).
5. **Tester** la migration sur un jeu de données représentatif (volumétrie proche de la prod si possible), dans les deux sens (application puis rollback).
6. **Documenter** tout changement de schéma qui affecte des clients externes (API, autres services) dans le changelog.

## Points d'attention

- Ne jamais exécuter une migration destructive (`DROP COLUMN`, `DROP TABLE`, troncature) directement sur une base de données de production sans confirmation explicite de l'utilisateur — c'est une action difficilement réversible.
