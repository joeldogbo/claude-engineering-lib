---
name: system-health
description: Diagnostique la lenteur du poste de travail — charge processeur, mémoire vive et swap, espace disque, état et usure de la batterie, processus les plus gourmands, poids des outils de développement (Claude Code, serveurs MCP, VS Code, navigateurs, Docker) — sous Windows, macOS et Linux, en lecture seule. Utiliser quand l'utilisateur signale un PC lent, une RAM saturée, une batterie qui se vide vite ou un ventilateur qui s'emballe.
---

# Santé du poste de travail

1. Lancer le script de ce skill adapté au système (dossier `.claude/skills/system-health/`, ou `skills/system-health/` dans le dépôt de la bibliothèque) :
   - Windows : `powershell -NoProfile -File .claude/skills/system-health/system-health.ps1` (ou `pwsh`) ;
   - macOS et Linux : `bash .claude/skills/system-health/system-health.sh`.
2. Le script est en lecture seule. Ne termine aucun processus, ne désinstalle rien, ne modifie ni le mode d'alimentation ni le démarrage, et ne supprime aucun fichier sans accord explicite de l'utilisateur pour chaque action.
3. Restituer les deux ou trois causes probables de lenteur, chiffres à l'appui, et les actions proposées, en suivant la grille d'interprétation de l'agent `system-monitor`.
