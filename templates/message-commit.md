# Gabarit de message de commit (Conventional Commits)

Voir [semver-conventional-commits.md](../standards/semver-conventional-commits.md) pour la sémantique complète.

```text
<type>(<scope>): <résumé au présent, sans majuscule finale, sans point>

<corps optionnel : le "pourquoi" du changement, pas le "quoi" — le diff montre déjà le quoi>

<footer optionnel : BREAKING CHANGE: ..., Closes #123>
```

## Exemples

```text
feat(auth): ajouter la connexion via Google OAuth

fix(registration): empêcher l'inscription en double sur le même événement

refactor(events): extraire la validation de date dans EventDateValidator

fix(api)!: renommer le champ `status` en `state` dans la réponse /orders

BREAKING CHANGE: les clients doivent utiliser `state` au lieu de `status`
```

## Règles

- Résumé court (< 72 caractères), à l'impératif présent ("ajouter", pas "ajouté" ni "ajoute").
- Un commit = un changement logique cohérent ; éviter de mélanger un `fix` et un `refactor` sans lien dans le même commit.
- Le scope est optionnel mais utile dans un projet multi-modules (`auth`, `api`, `events`...).
