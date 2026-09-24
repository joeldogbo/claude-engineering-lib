# Gabarit d'Architecture Decision Record (ADR)

Un ADR par décision architecturale significative et difficile à revenir en arrière. Nommer le fichier `NNNN-titre-court.md` (numérotation séquentielle).

```markdown
# NNNN. Titre court de la décision

Date : AAAA-MM-JJ
Statut : Proposé | Accepté | Remplacé par NNNN | Obsolète

## Contexte

Quel problème force cette décision ? Quelles contraintes (techniques, délai, équipe, existant) pèsent sur le choix ?

## Options considérées

- **Option A** : description, avantages, inconvénients
- **Option B** : description, avantages, inconvénients

## Décision

Option retenue et raison principale du choix.

## Conséquences

- Ce que cette décision facilite
- Ce qu'elle complique ou empêche
- Dette/risque assumé consciemment
```

## Quand écrire un ADR

- Choix de framework, de base de données, de pattern d'architecture (voir [clean-architecture-hexagonale.md](../standards/clean-architecture-hexagonale.md), [ddd-cqrs.md](../standards/ddd-cqrs.md)).
- Décision difficile/coûteuse à annuler, ou qui a suscité un débat entre plusieurs options valables.
- Ne pas créer d'ADR pour un choix trivial ou facilement réversible.
