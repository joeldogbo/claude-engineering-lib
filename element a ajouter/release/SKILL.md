---
name: release
description: >
  Orchestre la préparation complète d'une release : tests, sécurité, performances,
  documentation et déploiement. Déclencher quand l'utilisateur veut préparer une
  nouvelle version, tagger une release, ou livrer une version en production.
---

Lire CLAUDE.md pour connaître le stack, les commandes de test et le seuil de couverture du projet.

Demander le numéro de version si non fourni (format semver recommandé : MAJOR.MINOR.PATCH).

Lancer le workflow WF-5 via l'Orchestrateur dans cet ordre strict :
1. Testeur           → tous les tests (unit + rules allow/deny), couverture ≥ seuil CLAUDE.md
2. Auditeur Sécurité → audit des Security Rules + dépendances (npm audit sur les deux apps)
   ⚠️ Point de non-retour : aucune rule ouverte (`if true`), refus par défaut présent
3. DBA               → backup Firestore (firestore:export) avant toute migration de données prod
4. Fullstack + Perf  → perf : coût de lecture Firestore, bundle size, listeners temps réel
5. Réviseur          → revue de tous les changements depuis la dernière release
6. Documentation     → finaliser CHANGELOG : [Unreleased] → [VERSION]
7. DevOps            → CI vert (lint+test+rules) ; déploiement rules AVANT hosting + runbook de rollback (restore export)

Appliquer les règles de fail-fast à chaque étape.
