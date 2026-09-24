# Workflow : Préparation d'une release

Préparation complète d'une nouvelle version, jusqu'au tag et au déploiement. S'appuie sur `pre-production-review` pour les vérifications, et y ajoute le versionnement, la sauvegarde et l'ordre de déploiement.

1. **Numéro de version** : le demander s'il n'est pas fourni. Le proposer selon [semver-conventional-commits.md](../standards/semver-conventional-commits.md) à partir des commits depuis la dernière release (`feat` → mineure, `fix` → correctif, changement incompatible → majeure).
2. **Vérifications avant production** : `/workflow pre-production-review` en entier — tests (seuil de couverture du projet s'il en a un), sécurité, performance, configuration, CI. **Point de non-retour** : aucune règle d'accès ouverte à tous, refus par défaut en place.
3. **Revue des changements** : agent `code-reviewer` sur l'ensemble du diff depuis la dernière release, pas seulement le dernier commit.
4. **Sauvegarde** : agent `database` — sauvegarde ou export des données de production **avant** toute migration de données, avec la commande de restauration correspondante.
5. **Changelog** : agent `documentation` — renommer la section « Non publié » en `[VERSION] - date` ([entree-changelog.md](../templates/entree-changelog.md)).
6. **Plan de déploiement** : agent `devops` — ordre de déploiement (migrations et règles d'accès **avant** le code qui en dépend, serveur avant client), vérifications juste après (logs, métriques, endpoint de santé), et procédure de rollback écrite (restauration de la sauvegarde de l'étape 4 comprise).
7. **Tag et déploiement** : seulement après confirmation explicite de l'utilisateur pour chacune de ces actions.

## Points d'attention

- **Fail-fast** : une étape en échec arrête la release. Ne jamais taguer une version dont les tests ou la CI sont rouges.
- Créer un tag, publier une release ou déployer sont des actions visibles par d'autres et difficiles à défaire : ce workflow prépare tout, mais ne les déclenche jamais sans accord explicite.
