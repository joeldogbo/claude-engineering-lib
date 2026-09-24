# Bonnes pratiques de conception d'API REST

## Ressources et routes

- Les URLs désignent des ressources (noms), pas des actions (verbes) : `GET /orders/42`, pas `GET /getOrder?id=42`.
- Utiliser le pluriel de façon cohérente : `/users`, `/users/{id}`.
- Imbriquer les ressources seulement quand la relation est intrinsèque : `/users/{id}/orders` ; éviter l'imbrication à plus de 2 niveaux.

## Verbes HTTP

- `GET` : lecture, sans effet de bord, idempotent, cacheable.
- `POST` : création ou action non idempotente.
- `PUT` : remplacement complet d'une ressource, idempotent.
- `PATCH` : modification partielle.
- `DELETE` : suppression, idempotent.

## Codes de statut

- `200` succès avec contenu, `201` création (avec `Location`), `204` succès sans contenu.
- `400` requête invalide (validation), `401` non authentifié, `403` non autorisé, `404` ressource absente, `409` conflit d'état.
- `422` erreur de validation métier (si le framework la distingue de 400).
- `429` limite de débit dépassée.
- `5xx` réservé aux erreurs serveur réelles, jamais utilisé pour signaler une erreur métier attendue.

## Format des réponses

- Structure d'erreur cohérente sur toute l'API (code, message, détails de champ le cas échéant) — ne jamais faire varier le format d'une route à l'autre.
- Pagination explicite sur les collections (curseur ou `page`/`limit`), avec métadonnées (total, page suivante).
- Versionner l'API dès qu'un changement cassant est possible (`/v1/...` ou en-tête de version) — ne jamais casser un contrat existant sans version.

## Au-delà de REST

- **GraphQL** : un seul endpoint, le client choisit les champs ; attention au coût de requêtes profondément imbriquées (limiter la profondeur/complexité), erreurs renvoyées dans le corps même en HTTP 200.
- **gRPC** : contrat fort typé (protobuf), adapté à la communication interservices à faible latence ; versionner les messages de façon rétrocompatible (champs optionnels, jamais de renumérotation).
- **WebSocket** : adapté au temps réel bidirectionnel ; prévoir la reconnexion, l'authentification de la connexion (pas seulement de la requête initiale), et un format de message versionné.

## Documentation et contrat

- Documenter le contrat (OpenAPI/Swagger, schéma GraphQL, `.proto`...) et le garder synchronisé avec l'implémentation.
- Respecter le versionnage sémantique de l'API (voir [semver-conventional-commits.md](semver-conventional-commits.md)) pour communiquer l'impact des changements.
