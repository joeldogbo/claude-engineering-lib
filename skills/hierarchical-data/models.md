# Modèles de hiérarchie

## Les quatre modèles

| Modèle | Stockage | Lecture d'un sous-arbre | Écriture | À privilégier quand… | Limite principale |
|---|---|---|---|---|---|
| **Liste d'adjacence** | `parent_id` sur chaque ligne | requête récursive (CTE) | une ligne | les données changent souvent ; choix par défaut | chaque lecture profonde parcourt l'arbre niveau par niveau |
| **Représentation intervallaire** (*nested set*) | bornes `lft` et `rgt` (et souvent `depth`) | une seule condition sur les bornes | décale en moyenne la moitié des bornes de la table | lectures de sous-arbres très fréquentes, arbre presque figé | insertions, déplacements et écritures concurrentes coûteux |
| **Table de clôture** | une ligne par couple ancêtre-descendant, avec la distance | une jointure indexée | ajoute ou retire autant de lignes que d'ancêtres × descendants | ancêtres et descendants interrogés souvent, arbre qui bouge | taille de la table : jusqu'à n × profondeur lignes |
| **Chemin matérialisé** | chaîne `/1/4/17/` | `LIKE 'préfixe%'` sur un index | réécrit le chemin de tout le sous-arbre déplacé | fil d'Ariane, tri par chemin, profondeur limitée | longueur du chemin ; le préfixe doit se terminer par le séparateur |

Les modèles se combinent : `parent_id` comme source de vérité, plus une table de clôture ou des bornes recalculées comme index de lecture, à condition de les tenir à jour dans la même transaction.

## Choisir

1. **Partir de la liste d'adjacence.** Les requêtes récursives sont standard (SQL:1999) et couvrent la plupart des besoins.
2. Passer à un autre modèle seulement si une **mesure** montre que la lecture récursive est le goulot, ou pour un besoin précis :
   - beaucoup de lectures « tous les descendants / tous les ancêtres » sur un arbre qui bouge → **table de clôture** ;
   - arbre presque figé (nomenclature, plan comptable, catalogue publié), lectures massives de sous-arbres → **représentation intervallaire** ;
   - chemin complet affiché partout, tri hiérarchique → **chemin matérialisé** (ou type natif).
3. Écritures concurrentes fréquentes sur le même arbre : éviter la représentation intervallaire, dont chaque écriture verrouille une large partie de la table.

## Requêtes récursives selon le SGBD

| SGBD | Requête récursive | Particularités |
|---|---|---|
| PostgreSQL | `WITH RECURSIVE` (8.4 et plus) | type `ltree` (extension) pour les chemins ; clause `CYCLE` depuis la version 14 |
| MySQL | `WITH RECURSIVE` (8.0 et plus) | absent en 5.7 ; `cte_max_recursion_depth` limite la profondeur (1000 par défaut) |
| MariaDB | `WITH RECURSIVE` (10.2.2 et plus) | |
| SQL Server | `WITH` (sans le mot `RECURSIVE`, 2005 et plus) | `OPTION (MAXRECURSION n)` ; type natif `hierarchyid` |
| Oracle | `WITH` récursif (11g R2 et plus) | `CONNECT BY` historique, avec `NOCYCLE` |
| SQLite | `WITH RECURSIVE` (3.8.3 et plus) | |

Vérifie toujours la version réellement déployée en production, pas seulement celle du poste de développement.

Pour une base orientée documents : MongoDB fournit `$graphLookup` ; ailleurs, stocker le chemin ou la liste des ancêtres dans le document.

## Bibliothèques et ORM

La plupart des écosystèmes ont des paquets éprouvés (par exemple, pour PHP/Laravel `kalnoy/nestedset` ou `staudenmeir/laravel-adjacency-list`, pour Django `django-treebeard`, pour Rails `ancestry` ou `closure_tree`, TypeORM avec ses entités `@Tree`). Avant d'en ajouter un, vérifie avec l'agent `dependencies` qu'il est maintenu et compatible avec la version du framework, et compare avec une implémentation directe de quelques requêtes.
