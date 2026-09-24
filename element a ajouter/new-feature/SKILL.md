---
name: new-feature
description: >
  Orchestre la création d'une nouvelle fonctionnalité complète de bout en bout.
  Déclencher quand l'utilisateur veut ajouter une feature, implémenter une nouvelle
  capacité, créer un nouvel écran ou endpoint dans le projet.
---

Lire CLAUDE.md pour connaître le stack, les conventions et les commandes du projet.

Demander le nom de la fonctionnalité si non fourni.

Lancer le workflow WF-1 via l'Orchestrateur dans cet ordre strict :
1. Agenda      → plan détaillé + impact modèle Firestore et Security Rules + app(s) concernée(s)
2. Scout       → exploration du code existant lié à la feature
3. DBA         → modèle Firestore (collections, dénormalisation, index) si nécessaire
4. Spécialiste Firebase → Security Rules (accès + validation) AVANT le code client, couche api.ts
5. Codeur / Spécialiste Frontend → hooks React Query + composants (préciser frontend/ ou frontend-admin/)
6. Testeur     → tests de rules (allow/deny) + unitaires + E2E, seuil de couverture CLAUDE.md
7. Réviseur    → code review qualité, sécurité (rules!), performance
8. Documentation → mise à jour du modèle de données / rules + entrée CHANGELOG

Appliquer les règles de fail-fast : stopper le workflow si une étape échoue.
Afficher le rapport final structuré à la fin du workflow.
