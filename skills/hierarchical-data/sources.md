# Sources

## Référence principale

Frédéric Brouard (SQLPro), [Gestion d'arbres par représentation intervallaire](https://sqlpro.developpez.com/cours/arborescence/), publié en 2003, mis à jour en 2009.

**Repris ici** : le principe des bornes gauche et droite, numérotées par un parcours qui « enveloppe » l'arbre ; la reconnaissance des feuilles (`bd - bg = 1`) et des nœuds ; les requêtes de sous-arbre, de complément, d'ancêtres, de racine et de comptage ; l'insertion par décalage de deux unités ; la suppression d'une feuille ou d'un sous-arbre avec renumérotation ; la colonne de niveau ; l'usage d'une transaction en isolation `SERIALIZABLE` ; le jeu d'essai des familles de véhicules, réutilisé par le script de vérification.

**À lire avec recul** :

- **Le critère de choix est daté.** L'article recommande d'abandonner la liste d'adjacence dès qu'un arbre dépasse 5 niveaux, 100 éléments par niveau, 200 à 300 éléments, ou 50 % de lectures. Il se justifiait en 2003, quand la récursivité était coûteuse ou absente de certains SGBD. Les requêtes récursives (`WITH RECURSIVE`) sont aujourd'hui disponibles dans tous les grands SGBD (voir [models.md](models.md)) : ce choix se fait désormais sur mesure, pas sur ces seuils.
- **« Impossible en une seule requête »** : un seul `UPDATE` avec `CASE` décale les deux bornes (voir [sql-patterns.md](sql-patterns.md)).
- **L'exemple « tous les pères de Moto »** affiche `3-46 Transport` et `24-37 Terrestre`, incohérents avec le jeu d'essai de l'article (`1-44` et `22-35`). La requête est juste, l'affichage non.
- **La contrainte d'unicité sur les bornes**, proposée par l'article, entre en collision pendant les décalages dans les SGBD qui vérifient l'unicité ligne par ligne (voir [integrity.md](integrity.md)).
- **Les procédures stockées** de l'article sont en Transact-SQL (SQL Server) : elles illustrent la logique, elles ne sont pas portables.

## Méthode

Aucune requête de ce skill n'est recopiée sans être exécutée : [verify_hierarchies.py](verify_hierarchies.py) rejoue chaque modèle sur SQLite et compare les résultats attendus. Pour un autre SGBD, adapte la syntaxe signalée et rejoue les cas de [test-cases.md](test-cases.md).
