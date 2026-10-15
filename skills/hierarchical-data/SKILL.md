---
name: hierarchical-data
description: Conception et maintenance de données hiérarchiques en base relationnelle — catégories et sous-catégories, organigrammes, dossiers, menus, commentaires imbriqués, nomenclatures. Compare liste d'adjacence (parent_id + requêtes récursives), représentation intervallaire (nested set), table de clôture et chemin matérialisé, puis fournit des requêtes vérifiées, les invariants d'intégrité (cycles, bornes) et les cas de test. Utiliser pour modéliser un arbre, choisir ou changer de modèle, corriger une hiérarchie corrompue ou accélérer la lecture d'un sous-arbre.
---

# Données hiérarchiques

Les fiches de ce dossier sont lues à la demande : ne charge que celle dont la tâche a besoin.

| Fiche | Contenu |
|---|---|
| [models.md](models.md) | les quatre modèles, critères de choix, prise en charge par SGBD, types natifs |
| [sql-patterns.md](sql-patterns.md) | requêtes vérifiées : lecture, insertion, suppression, déplacement, pour chaque modèle |
| [integrity.md](integrity.md) | invariants, requêtes d'audit, transactions et concurrence |
| [test-cases.md](test-cases.md) | scénarios de test à reprendre dans le projet |
| [verify_hierarchies.py](verify_hierarchies.py) | 55 contrôles exécutables sur SQLite (`python verify_hierarchies.py`) qui prouvent les requêtes des fiches |
| [sources.md](sources.md) | sources, ce qui en est repris et ce qui est daté |

## Procédure

1. **Détecter le SGBD et sa version** (skill `stack-detection`) : les requêtes récursives, les contraintes différées et les types natifs en dépendent. Repérer aussi ce que l'ORM et les paquets installés offrent déjà.
2. **Qualifier le besoin**, chiffres à l'appui quand ils existent : nombre de nœuds, profondeur, largeur, fréquence des lectures de sous-arbres et d'ancêtres, fréquence des insertions, déplacements et suppressions, écritures concurrentes.
3. **Choisir le modèle** avec [models.md](models.md). Par défaut, la liste d'adjacence avec requêtes récursives : simple, robuste, suffisante dans la plupart des cas. Un autre modèle se justifie par une mesure ou un besoin précis, jamais par principe.
4. **Écrire le schéma** : clés étrangères, contraintes, index adaptés aux requêtes réelles.
5. **Encapsuler chaque modification de l'arbre dans une transaction**, avec les garde-fous de [integrity.md](integrity.md) : pas de cycle, pas de parent inexistant, bornes cohérentes.
6. **Tester** avec [test-cases.md](test-cases.md) : racine, feuilles, sous-arbres, déplacements, suppressions, cycles refusés, invariants après chaque écriture.
7. **Mesurer** avant et après, sur un volume représentatif (plan d'exécution, temps), avec l'agent `performance` quand la vitesse est en jeu.
8. **Documenter** le choix du modèle dans un ADR (skill `documentation-standards`), avec ses limites.

## Règles impératives

- Ne jamais choisir la représentation intervallaire seulement parce que ses lectures sont simples : chaque insertion, suppression ou déplacement réécrit une partie de la table.
- Ne jamais affirmer qu'un modèle est plus rapide sans mesure sur un volume représentatif.
- Ne jamais déplacer ni supprimer un sous-arbre sans règle d'intégrité explicite : sort des enfants, refus des cycles, suppression en cascade ou interdite.
- Ne jamais poser d'index UNIQUE ordinaire sur des bornes d'intervalle : la plupart des SGBD vérifient l'unicité ligne par ligne et le décalage des bornes entre en collision (voir [integrity.md](integrity.md)).
- Ne jamais lancer de migration destructive (changement de modèle, recalcul des bornes) sans sauvegarde, test sur une copie et plan de retour arrière.
- Distinguer le SQL standard des syntaxes propres à un SGBD, et le dire.
- Les exemples des fiches sont des modèles à adapter au schéma, aux conventions et au SGBD du projet, pas du code à copier tel quel.

## Restitution

1. Besoin analysé (volumes, opérations fréquentes).
2. Modèle recommandé et justification, alternatives écartées et pourquoi.
3. Schéma SQL ou migration.
4. Requêtes et implémentation des opérations.
5. Index et stratégie de performance, avec mesures.
6. Tests et contrôles d'intégrité.
7. Risques, hypothèses et maintenance.
