---
name: review-mr
description: >
  Orchestre une revue complète de Pull Request ou Merge Request.
  Déclencher quand l'utilisateur veut faire réviser une PR, une MR, un diff git,
  ou obtenir un verdict avant de merger du code dans la branche principale.
---

Lire CLAUDE.md pour connaître les conventions, le stack et les critères de qualité du projet.

Demander le diff git ou le titre de la MR/PR si non fourni.
Obtenir le diff avec : git diff main...HEAD

Lancer le workflow WF-6 via l'Orchestrateur dans cet ordre strict :
1. Scout       → cartographier les fichiers modifiés et leur rôle dans le projet
2. Réviseur    → revue qualité : conventions CLAUDE.md, DRY, nommage, sécurité (rules!), performance
3. Testeur     → vérifier que les tests couvrent les changements (dont tests de rules si rules touchées)
4. Auditeur    → vérification sécurité ciblée : Security Rules modifiées, accès, exposition côté client
5. Verdict     → Approuvé ✅ / Approuvé avec réserves ⚠️ / Changements requis ❌

Format de sortie : rapport de revue structuré avec points positifs, problèmes critiques, améliorations recommandées.
