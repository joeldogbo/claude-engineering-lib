---
name: prompt-writer
description: Réécrit un brouillon de demande en prompt clair et complet avant de l'exécuter — objectif, périmètre, résultat attendu, contraintes — pour éviter les allers-retours et les tâches refaites qui gaspillent des jetons. Invoquer avec /prompt-writer suivi du brouillon.
argument-hint: <brouillon de la demande>
disable-model-invocation: true
---

# Rédaction de prompt

Le brouillon est : `$ARGUMENTS`. S'il est vide, demander le brouillon et s'arrêter là.

## Instructions

1. **Comprendre l'intention** : quel résultat l'utilisateur veut obtenir, et à quoi il verra que c'est réussi.
2. **Repérer ce qui manque et ferait refaire le travail** — seulement ça :
   - le périmètre : quels fichiers, quel module, quelle application, quel environnement ;
   - le résultat attendu : code modifié, analyse, document, commande à lancer ;
   - les contraintes : ce qu'il ne faut pas toucher, la compatibilité à garder, le style à suivre ;
   - le critère de fin : tests qui passent, comportement observable, livrable précis.
   Chercher d'abord la réponse dans le projet (fichiers, `CLAUDE.md`, historique de la conversation) avant de la demander.
3. **Questions** : au plus trois, et uniquement si la réponse change vraiment le travail. Sinon, faire une hypothèse raisonnable et l'écrire dans le prompt.
4. **Rédiger le prompt** dans un bloc, court et sans remplissage, avec ces rubriques quand elles s'appliquent : **Objectif**, **Contexte** (fichiers, stack), **Contraintes**, **Résultat attendu**, **Hypothèses**. Indiquer en une ligne quel workflow (`/workflow <nom>`) ou quels agents s'en chargeront.
5. **Demander confirmation** : « J'exécute ce prompt ? ». Sur accord, l'exécuter tel quel, sans le reformuler une seconde fois.

## Ce qu'il ne faut pas faire

- Allonger le prompt pour faire sérieux : un bon prompt est complet, pas long.
- Changer l'intention de l'utilisateur ou y ajouter des tâches qu'il n'a pas demandées.
- Poser des questions dont la réponse se trouve dans le projet.
