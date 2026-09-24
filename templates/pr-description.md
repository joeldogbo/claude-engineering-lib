# Gabarit de description de Pull Request

```markdown
## Résumé

- Point clé 1 (le "pourquoi", pas juste le "quoi")
- Point clé 2
- Point clé 3 (si nécessaire)

## Contexte / Motivation

Pourquoi ce changement est nécessaire (bug rencontré, besoin utilisateur, dette technique...).

## Changements

- Changement principal et son impact
- Changements secondaires notables (migrations, config, dépendances)

## Plan de test

- [ ] Étape de vérification manuelle 1
- [ ] Étape de vérification manuelle 2
- [ ] Tests automatisés ajoutés/mis à jour
- [ ] Testé sur [environnement/navigateur/OS si pertinent]

## Risques / points d'attention

- Ce qui pourrait casser, ce qui nécessite une vigilance au déploiement (migration, feature flag, rollback)

## Captures d'écran (si UI)
```

## Règles d'usage

- Le titre reste court (< 70 caractères), le détail va dans le corps.
- Ne pas lister tous les fichiers modifiés — le diff les montre déjà ; se concentrer sur l'intention.
- Si le changement est un breaking change, le signaler explicitement en premier.
