---
name: token-usage
description: Mesure la consommation de jetons de Claude Code à partir de ses journaux locaux — par jour, par projet, par modèle, conversation principale contre sous-agents, sessions les plus coûteuses — sans lire le contenu des conversations. Utiliser quand l'utilisateur demande combien il consomme, pourquoi il atteint ses limites, ou ce qui coûte le plus.
argument-hint: [nombre de jours, 7 par défaut]
---

# Consommation de jetons Claude Code

1. Lancer le script fourni avec ce skill (`.claude/skills/token-usage/token_usage.py`, ou `skills/token-usage/` dans le dépôt de la bibliothèque) avec le premier interpréteur Python 3 disponible (`python3`, `python` ou `py`) :
   `python3 .claude/skills/token-usage/token_usage.py --days <jours>` — `<jours>` vaut `$ARGUMENTS` s'il est fourni, sinon 7. Ajouter `--project <texte>` pour se limiter à un projet.
2. Ne jamais lire les fichiers de journaux directement : ils sont volumineux (lire un seul fichier peut coûter plus que ce qu'on cherche à économiser) et contiennent les conversations. Le script n'en extrait que les compteurs.
3. Sans Python, le dire et proposer de l'installer. L'outil communautaire `ccusage` (via `npx`) lit les mêmes journaux, mais télécharge du code : ne le lancer qu'avec l'accord de l'utilisateur.
4. Restituer le total, les postes principaux et deux ou trois actions concrètes, en suivant la grille d'interprétation de l'agent `token-monitor`. Ne jamais convertir en euros avec des tarifs cités de mémoire : `/cost` donne le coût de la session en cours, et la grille tarifaire officielle fait foi pour le reste.
