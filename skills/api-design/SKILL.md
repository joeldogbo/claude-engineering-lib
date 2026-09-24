---
name: api-design
description: Bonnes pratiques de conception d'API — REST, GraphQL, gRPC, WebSocket. Utiliser pour concevoir ou revoir un endpoint/contrat d'API, quel que soit le style utilisé par le projet.
---

# Conception d'API

## Instructions

1. Détecter le style d'API déjà utilisé dans le projet (REST/GraphQL/gRPC/WebSocket) et s'y conformer plutôt que d'introduire un style différent sans raison.
2. Appliquer [rest-api-design.md](../../standards/rest-api-design.md) pour :
   - Nommage des ressources, verbes HTTP, codes de statut cohérents avec le reste de l'API.
   - Format d'erreur homogène sur toute l'API.
   - Pagination/filtrage pour toute collection potentiellement large.
   - Versionnement en cas de changement incompatible.
3. Pour GraphQL : attention à la profondeur/complexité des requêtes imbriquées, cohérence du schéma avec le domaine.
4. Pour gRPC : compatibilité ascendante des messages protobuf (champs optionnels, jamais de renumérotation de champ existant).
5. Pour WebSocket : authentification de la connexion elle-même (pas seulement de la requête initiale), gestion de la reconnexion, format de message versionné.
6. Vérifier qu'aucune donnée sensible (mot de passe, token, donnée d'un autre utilisateur) n'est exposée par défaut, y compris via une sérialisation automatique d'ORM.

## Restitution

Contrat proposé ou constats sur le contrat existant, avec justification par rapport à la convention déjà en place dans le projet.
