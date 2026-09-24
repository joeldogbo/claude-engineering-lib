# Semantic Versioning et Conventional Commits

## Semantic Versioning (SemVer)

Format `MAJOR.MINOR.PATCH` :

- **MAJOR** : changement incompatible avec les versions précédentes (breaking change).
- **MINOR** : ajout de fonctionnalité rétrocompatible.
- **PATCH** : correction de bug rétrocompatible.

Avant la 1.0.0, l'API est considérée instable (tout peut changer). Une pré-release s'indique par un suffixe (`1.2.0-beta.1`).

## Conventional Commits

Format : `<type>(<scope optionnel>): <description>`

Types courants :
- `feat` : nouvelle fonctionnalité (→ MINOR)
- `fix` : correction de bug (→ PATCH)
- `refactor` : changement de code sans changement de comportement observable
- `perf` : amélioration de performance
- `test` : ajout/modification de tests
- `docs` : documentation uniquement
- `build`/`chore` : outillage, dépendances, configuration
- `ci` : pipeline d'intégration continue

Un breaking change s'indique par `!` après le type/scope (`feat!:`) ou un footer `BREAKING CHANGE: ...` → force un bump MAJOR.

## Pourquoi c'est utile ensemble

- Un historique de commits conventionnel permet de **générer automatiquement** le changelog et de déduire le prochain numéro de version sans jugement humain à chaque release.
- Le message décrit le **pourquoi**, le diff montre déjà le **quoi** — éviter les messages du type "fix bug" ou "update file" sans contexte.
- Voir le template [message-commit.md](../templates/message-commit.md) et [entree-changelog.md](../templates/entree-changelog.md).
