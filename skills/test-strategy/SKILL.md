---
name: test-strategy
description: Stratégie de tests — unitaires, intégration, fonctionnels, end-to-end, performance, sécurité — sans imposer de framework de test particulier. Utiliser pour définir ou compléter la couverture de tests d'une fonctionnalité ou d'un correctif.
---

# Stratégie de tests

## Instructions

1. Détecter le framework de test déjà utilisé dans le projet (skill `stack-detection`) et l'utiliser plutôt que d'en introduire un nouveau.
2. Choisir le niveau de test adapté au risque, pas systématiquement le plus lourd :
   - **Unitaire** : logique métier pure, fonctions/classes isolées, cas limites (valeurs nulles, vides, extrêmes).
   - **Intégration** : interaction entre plusieurs composants réels (BDD, service externe simulé).
   - **Fonctionnel/E2E** : parcours utilisateur complet, réservé aux chemins critiques (trop coûteux à maintenir pour tout couvrir).
   - **Performance** : sur les chemins à fort trafic ou identifiés comme sensibles (voir skill `performance-audit`).
   - **Sécurité** : cas d'autorisation refusée, entrées malveillantes sur les points d'entrée exposés (voir skill `security-audit`).
3. Couvrir systématiquement : le cas nominal, les cas limites évidents, et le(s) cas d'échec attendu (erreur gérée proprement).
4. Ne pas tester l'implémentation interne (détails qui changent lors d'un refactoring) mais le comportement observable.
5. Un test doit échouer pour une seule raison identifiable — éviter les tests qui vérifient plusieurs choses sans lien.

## Restitution

Proposer les tests manquants les plus importants en premier (risque × probabilité), pas une liste exhaustive théorique de tous les tests possibles.
