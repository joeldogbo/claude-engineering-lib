# Workflow : Revue avant mise en production

1. **Tests** : la suite complète (unitaire, intégration, E2E si disponible) passe — agent `testing`.
2. **Sécurité** : `/workflow security-audit` sur les changements récents, en particulier tout ce qui touche auth/permissions/entrées utilisateur.
3. **Performance** : vérifier qu'aucune régression de performance évidente n'a été introduite (skill `performance-audit`) sur les chemins critiques.
4. **Migrations de base de données** : vérifier qu'elles sont sûres à exécuter sur les données de production (voir `/workflow db-migration`), et qu'un plan de rollback existe.
5. **Configuration/secrets** : variables d'environnement de production présentes et correctes, aucun secret en dur, aucune configuration de debug/développement active (stack traces exposées, logs verbeux, mode debug).
6. **CI/CD** : le pipeline de déploiement est vert, la stratégie de rollback est connue et testée (agent `devops` + skill `cicd-pipeline`).
7. **Documentation** : changelog à jour ([entree-changelog.md](../templates/entree-changelog.md)), documentation utilisateur mise à jour si le comportement visible change.
8. **Plan de vérification post-déploiement** : que va-t-on observer juste après le déploiement pour confirmer que tout fonctionne (logs, métriques, endpoint de santé) ?

## Points d'attention

- Toute action de déploiement effective (pousser en prod, exécuter une migration sur la base de production, activer un feature flag global) nécessite une confirmation explicite de l'utilisateur — ce workflow prépare et vérifie, il ne déclenche pas le déploiement lui-même.
