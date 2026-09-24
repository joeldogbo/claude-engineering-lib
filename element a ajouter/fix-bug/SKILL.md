---
name: fix-bug
description: >
  Orchestre la correction d'un bug par root cause analysis rigoureuse.
  Déclencher quand l'utilisateur signale une erreur, un crash, un comportement
  inattendu, une régression ou un dysfonctionnement dans le projet.
---

Lire CLAUDE.md pour connaître le stack, les conventions et les commandes du projet.

Demander la description du bug si non fournie.

Lancer le workflow WF-2 via l'Orchestrateur dans cet ordre strict :
1. Débogueur   → root cause analysis (RCA) — identifier fichier et ligne, preuve requise
2. Scout       → exploration du contexte autour du bug
3. Codeur      → correction minimale et ciblée, pas de refactoring connexe
4. Testeur     → écrire le test qui échoue sans le fix et passe avec
5. Réviseur    → validation que le fix ne provoque pas de régression
6. Documentation → entrée CHANGELOG si le bug était visible côté utilisateur

Ne jamais corriger sans avoir d'abord compris la cause racine.
Appliquer les règles de fail-fast : stopper si la cause racine n'est pas identifiée avec preuve.
