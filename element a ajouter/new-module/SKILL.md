---
name: new-module
description: >
  Orchestre la création complète d'un nouveau module applicatif (scaffold).
  Déclencher quand l'utilisateur veut créer un nouveau module, un nouveau domaine
  métier, une nouvelle ressource API, ou scaffolder une nouvelle section du projet.
---

Lire CLAUDE.md pour connaître le stack, la structure du projet et les conventions de nommage.

Demander le nom du module si non fourni.

Lancer le workflow WF-4 via l'Orchestrateur dans cet ordre strict :
1. Agenda            → architecture du module : collections, écrans, rôles, app(s) concernée(s)
2. DBA               → modèle Firestore + index composites (+ script de migration si données existantes)
3. Spécialiste Firebase → Security Rules + couche d'accès typée (api.ts, converters, schemas Zod)
4. Spécialiste Frontend → scaffold frontend : hooks React Query, store Zustand, composants, routes
5. Testeur           → fixtures/factories + tests de rules (allow/deny) pour le nouveau module
6. Documentation     → modèle de données (docs/DATA_MODEL.md) + README du module
7. DevOps            → vérification que rules + apps sont déployables

Appliquer les règles de fail-fast : stopper si les Security Rules manquent ou ne sont pas testées.
