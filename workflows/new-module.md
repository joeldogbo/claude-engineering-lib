# Workflow : Création d'un nouveau module

Création complète d'un nouveau module applicatif — un domaine métier, une ressource d'API, une section de l'application — de la donnée à l'interface. À distinguer de `feature-development`, qui ajoute une capacité à un module existant.

1. **Détecter la stack** (skill `stack-detection`) et relever la structure des modules existants : c'est elle que le nouveau module doit reproduire (arborescence, nommage, découpage en couches).
2. **Clarifier le périmètre** : nom du module (le demander s'il n'est pas fourni), entités manipulées, écrans ou endpoints attendus, rôles utilisateurs concernés, application(s) touchée(s) quand le dépôt en contient plusieurs.
3. **Architecture** : agent `architect` — place du module, dépendances autorisées vers les autres modules, ce qui est partagé et ce qui reste interne.
4. **Modèle de données** : agent `database` + skill `database-design` — schéma ou collections, index pour les requêtes prévues, et migration de reprise si des données existantes sont concernées (voir `/workflow db-migration`).
5. **Règles d'accès et couche d'accès aux données** : agents `backend`/`api` — contrôle d'accès et validation côté serveur (policy, middleware, guard, règles de sécurité d'un BaaS), puis couche d'accès typée (repository, service, client d'API, schémas de validation) **avant** tout code d'interface.
6. **Interface** : agent `frontend` — écrans, composants, état, routes, en réutilisant les composants et conventions des modules existants.
7. **Tests** : agent `testing` — jeux de données de test (fixtures/factories), tests unitaires de la logique métier, et un test **autorisé** + un test **refusé** pour chaque règle d'accès.
8. **Documentation** : agent `documentation` — modèle de données du module et README du module si le projet en maintient un par module.
9. **Déployabilité** : agent `devops` — le module est pris en compte par le build, la CI et le déploiement (règles d'accès et migrations comprises).

## Points d'attention

- **Fail-fast** : pas de code d'interface tant que les règles d'accès de l'étape 5 ne sont pas écrites **et testées**.
- Un module qui ne ressemble pas aux autres est un coût de maintenance : en cas de doute, copier la structure du module existant le plus proche plutôt qu'inventer.
- Ne pas générer d'écrans ou d'endpoints « au cas où » : seulement ceux identifiés à l'étape 2 (voir [dry-kiss-yagni.md](../standards/dry-kiss-yagni.md)).
