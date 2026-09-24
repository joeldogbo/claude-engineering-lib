---
name: code-quality
description: Checklist de revue de qualité de code (lisibilité, duplication, complexité, dette technique, conventions, commentaires). Utiliser après avoir écrit ou modifié du code, ou quand l'utilisateur demande une revue de qualité.
---

# Qualité de code

## Instructions

Vérifier, en s'appuyant sur [Clean Code](../../standards/clean-code.md) et [DRY/KISS/YAGNI](../../standards/dry-kiss-yagni.md) :

1. **Lisibilité** : les noms révèlent-ils l'intention ? Le niveau d'abstraction est-il cohérent dans chaque fonction ?
2. **Duplication** : la même règle métier est-elle codée à plusieurs endroits (source d'incohérence future) ?
3. **Complexité** : imbrication excessive, fonctions trop longues, trop de paramètres, trop de branches conditionnelles.
4. **Conventions du projet** : le code suit-il le style déjà en place (nommage, organisation des fichiers) plutôt que d'introduire une convention différente ?
5. **Commentaires** : utiles (expliquent un "pourquoi" non évident) ou superflus (répètent ce que le code dit déjà) ? Code mort commenté à supprimer ?
6. **Gestion d'erreurs** : erreurs silencieusement avalées, cas limites non gérés ?
7. **Dette technique** : `TODO`/raccourcis non documentés qui mériteraient de l'être.

## Restitution

Constats classés bloquant / à corriger / suggestion, avec fichier:ligne et exemple concret. Ne pas remonter de préférence purement stylistique sans justification si elle contredit la convention déjà utilisée dans le projet.
