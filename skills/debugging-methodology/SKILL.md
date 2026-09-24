---
name: debugging-methodology
description: Méthodologie complète de débogage — reproduire un bug, isoler la cause, analyser les logs, identifier la racine du problème, proposer une correction durable. Utiliser face à un bug, une erreur inexpliquée, ou un comportement inattendu.
---

# Méthodologie de débogage

## Instructions

1. **Reproduire** de façon fiable et minimale — réduire le cas au plus petit scénario qui déclenche encore le problème.
2. **Formuler des hypothèses** sur la cause avant de modifier du code, plutôt que de tâtonner par essais-erreurs.
3. **Isoler** : ajouter des points d'observation (logs, breakpoints, valeurs intermédiaires) pour confirmer ou éliminer chaque hypothèse une à une.
4. **Analyser les logs/traces** disponibles avant d'en ajouter de nouveaux — l'information est parfois déjà présente.
5. **Identifier la cause racine**, pas seulement le point où l'erreur devient visible (l'endroit où ça casse n'est souvent pas l'endroit où le problème a été introduit).
6. **Vérifier la portée** : le même défaut existe-t-il ailleurs par un pattern similaire ?
7. **Corriger à la racine** et ajouter un test qui aurait échoué avant le correctif.

## Anti-patterns à éviter

- Corriger le symptôme visible sans comprendre la cause (le bug réapparaîtra sous une autre forme).
- Modifier plusieurs choses à la fois en espérant que "ça marche" sans savoir laquelle a résolu le problème.
- Supprimer ou désactiver un test qui échoue au lieu de comprendre pourquoi il échoue.
