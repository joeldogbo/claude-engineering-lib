# Workflow : Création d'une API

1. **Détecter la stack** et le style d'API déjà en place dans le projet (REST/GraphQL/gRPC/WebSocket) — suivre la convention existante plutôt que d'en introduire une nouvelle sans raison.
2. **Concevoir** avec l'agent `api` + skill `api-design`, en s'appuyant sur [rest-api-design.md](../standards/rest-api-design.md) :
   - Ressources, verbes, codes de statut cohérents avec le reste de l'API existante
   - Contrat de validation des entrées et format d'erreur homogène
   - Pagination/filtrage pour toute collection potentiellement large
3. **Sécuriser** : authentification/autorisation de chaque endpoint, validation stricte des entrées (skill `security-audit`).
4. **Implémenter** : agent `backend`.
5. **Documenter le contrat** (OpenAPI/schéma GraphQL/`.proto` selon le style détecté) et le garder synchronisé avec l'implémentation.
6. **Tester** : cas nominaux, erreurs de validation, cas d'autorisation refusée (agent `testing`).
7. **Versionner** si le changement est incompatible avec les clients existants (voir [semver-conventional-commits.md](../standards/semver-conventional-commits.md)).

## Points d'attention

- Ne jamais exposer de champ sensible (mot de passe, token interne, donnée d'un autre utilisateur) dans une réponse, même par défaut/implicitement via un ORM qui sérialise tout un modèle.
