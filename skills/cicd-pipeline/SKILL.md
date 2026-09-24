---
name: cicd-pipeline
description: Bonnes pratiques de pipeline CI/CD — build, qualité, déploiement, rollback, automatisation. Utiliser pour concevoir ou revoir un pipeline d'intégration/déploiement continu, quel que soit l'outil utilisé.
---

# Pipeline CI/CD

## Instructions

1. Détecter l'outil CI/CD déjà utilisé (`.github/workflows/`, `.gitlab-ci.yml`, `Jenkinsfile`, autre) et suivre sa convention plutôt que d'en introduire un nouveau.
2. **Build** : reproductible (versions figées des dépendances), échoue vite en cas de problème (fail fast).
3. **Qualité** : lint, tests, et si présents analyse statique/sécurité exécutés systématiquement avant tout déploiement — jamais contournés (`--no-verify` ou équivalent) sans raison documentée et explicite.
4. **Déploiement** : étapes idempotentes, secrets injectés de façon sécurisée (jamais en clair dans le pipeline), environnements clairement séparés (dev/staging/prod).
5. **Rollback** : un mécanisme de retour en arrière rapide existe et est testé, pas seulement théorique.
6. **Automatisation** : toute étape manuelle répétée à chaque déploiement est un candidat à l'automatisation, sauf si elle sert de garde-fou volontaire (validation humaine avant prod).

## Restitution

Constats classés par risque (ce qui pourrait causer un incident de production) avant les améliorations de confort.
