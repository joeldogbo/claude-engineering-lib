# Clean Code

Repères pratiques, indépendants du langage.

## Nommage

- Noms révélateurs d'intention : `getActiveUsers()` plutôt que `getData()`.
- Pas d'abréviations obscures ; un nom long et clair vaut mieux qu'un nom court et ambigu.
- Un booléen se lit comme une question : `isValid`, `hasPermission`, `canEdit`.
- Un nom de fonction est un verbe ; un nom de classe/variable est un nom commun.

## Fonctions

- Une fonction fait une seule chose, à un seul niveau d'abstraction.
- Peu de paramètres (au-delà de 3-4, regrouper dans un objet/structure).
- Pas d'effets de bord cachés qui contredisent le nom de la fonction.
- Préférer retourner une valeur plutôt que muter un paramètre en argument, sauf convention explicite du langage.

## Commentaires

- Le code doit d'abord s'expliquer par lui-même (nommage, structure).
- Un commentaire utile explique le **pourquoi** (contrainte cachée, contournement d'un bug, décision non évidente), jamais le **quoi** (déjà lisible dans le code).
- Supprimer le code commenté mort — l'historique Git le conserve déjà.

## Structure

- Éviter la duplication (voir [dry-kiss-yagni.md](dry-kiss-yagni.md)).
- Limiter la profondeur d'imbrication (`if` dans `if` dans `for`...) — extraire des fonctions ou inverser les conditions (early return).
- Gérer les erreurs explicitement ; ne jamais avaler une exception silencieusement sans raison documentée.
- Garder les fichiers et fonctions à une taille lisible d'une traite ; un fichier de plusieurs milliers de lignes est un signal de découpage à envisager.

## Dette technique

- Un `TODO`/`FIXME` doit décrire le problème concret, pas juste "à améliorer".
- Documenter les raccourcis pris sous contrainte de délai pour qu'ils soient traçables et priorisables plus tard.
