# Domain-Driven Design (DDD) et CQRS

À utiliser uniquement quand la complexité métier le justifie (voir section finale).

## DDD — concepts clés

- **Langage ubiquitaire** : le code utilise le vocabulaire exact des experts métier, pas une traduction technique approximative.
- **Bounded context** : un même mot peut avoir un sens différent selon le contexte métier (ex. "Client" en facturation vs en support) — ne pas forcer un modèle unique partagé partout.
- **Entité** : objet défini par son identité, qui persiste dans le temps même si ses attributs changent (ex. un `Compte`).
- **Value Object** : objet défini par ses attributs, immuable, sans identité propre (ex. une `Adresse`, un `Montant`).
- **Agrégat** : groupe d'entités/value objects traité comme une unité de cohérence transactionnelle, avec une racine (`Aggregate Root`) qui contrôle les accès.
- **Domain Service** : logique métier qui n'appartient naturellement à aucune entité.
- **Domain Event** : fait métier significatif qui s'est produit (`CommandeValidee`, `PaiementRefuse`), utile pour découpler les réactions à cet événement.

## CQRS — Command Query Responsibility Segregation

Séparer les opérations qui **modifient** l'état (commandes) de celles qui **lisent** l'état (requêtes), potentiellement avec des modèles de données différents pour chacune.

- Une commande ne retourne pas de données métier (au mieux un identifiant/statut) ; elle produit un effet de bord.
- Une requête ne modifie jamais l'état.
- Utile quand les besoins de lecture (ex. tableaux de bord, recherche) divergent fortement des besoins d'écriture (validation, cohérence transactionnelle) — permet d'optimiser chaque côté indépendamment, y compris avec un modèle de lecture dénormalisé.

## Quand appliquer / éviter

- **Appliquer** DDD sur un domaine métier riche, avec des règles complexes qui évoluent souvent et une équipe qui bénéficie d'un vocabulaire partagé précis.
- **Appliquer** CQRS quand lecture et écriture ont des contraintes de performance ou de modélisation vraiment différentes.
- **Éviter les deux** sur une application CRUD simple : le surcoût de conception (agrégats, découpage commande/requête, event sourcing éventuel) dépasse largement le bénéfice. Un modèle de données classique et des services simples suffisent (voir [dry-kiss-yagni.md](dry-kiss-yagni.md)).
