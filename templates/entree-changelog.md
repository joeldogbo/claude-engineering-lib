# Gabarit d'entrée de changelog

Format inspiré de [Keep a Changelog](https://keepachangelog.com/), aligné sur [semver-conventional-commits.md](../standards/semver-conventional-commits.md).

```markdown
## [1.2.0] - AAAA-MM-JJ

### Ajouté
- Nouvelle fonctionnalité X (impact utilisateur, pas détail d'implémentation)

### Modifié
- Comportement Y désormais différent, et pourquoi

### Corrigé
- Bug Z qui causait tel symptôme

### Cassé (breaking changes)
- Ce qui ne fonctionne plus comme avant et comment migrer

### Déprécié
- Fonctionnalité encore disponible mais qui sera retirée, avec date/version cible

### Sécurité
- Faille corrigée (sans détailler l'exploit si publié avant le correctif)
```

## Règles

- Écrit du point de vue de l'utilisateur/consommateur de l'API, pas du point de vue du code interne.
- Une entrée par changement notable ; regrouper les changements internes sans impact visible (refactor pur) dans une section "Interne" facultative, ou les omettre.
- Le numéro de version suit SemVer en fonction du contenu de la section (breaking → MAJOR, ajout → MINOR, correction seule → PATCH).
