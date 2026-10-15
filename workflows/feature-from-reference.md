# Workflow : Fonctionnalité inspirée d'une application existante

Pour « je veux la même chose que dans telle appli, en mieux ». La référence est étudiée preuves à l'appui, puis la fonctionnalité est reconstruite dans le projet à partir d'une fiche, jamais à partir du code de la référence.

1. **Cadrer** : application, version, plateforme et fonctionnalité exactes, désignées par l'utilisateur ; ce qu'il veut garder et ce qu'il veut faire mieux. Ouvrir le point de reprise `.claude/progress/<fonctionnalité>.md`.
2. **Étudier la référence** : agent `reverse-engineering` + skill `reverse-engineering`. Livrable : fiche [fiche-fonctionnalite.md](../templates/fiche-fonctionnalite.md) avec registre des preuves (observé / déduit / inconnu), forces et faiblesses, version proposée et critères d'acceptation.
3. **Lever les doutes** : licence ou conditions d'utilisation incertaines → agent `legal` (ne remplace pas un juriste) ; ergonomie de la version proposée → agent `ux-ui` si la fonctionnalité a une interface.
4. **Valider avec l'utilisateur** : présenter ce qui est repris, amélioré et écarté, et les points ouverts. **Ne pas implémenter sans son accord** sur la fiche.
5. **Implémenter** : suivre `/workflow feature-development` avec la fiche comme spécification — agents `frontend`, `backend`, `api`, `database` selon les couches touchées, en parallèle quand ils sont indépendants. Chaque comportement implémenté renvoie à son critère d'acceptation.
6. **Vérifier la reconstruction** : agent `testing` transforme les critères d'acceptation en tests ; les mêmes scénarios sont rejoués sur la référence quand c'est possible, et les résultats notés dans la section « Vérification » de la fiche.
7. **Revue** : `code-reviewer` ; `security` si la fonctionnalité touche des entrées utilisateur, des données sensibles ou des échanges réseau ; `accessibility` et `ux-ui` pour une interface.
8. **Clore** : chaque question de la fiche est résolue, partielle ou non résolue ; la fiche reste dans `.claude/references/` pour les évolutions suivantes ; entrée de changelog si la fonctionnalité est visible (agent `documentation`).

## Points d'attention

- Salle blanche : aucun code propriétaire, texte, visuel, icône, police ou marque de la référence dans le projet. Code libre seulement si la licence est compatible, avec attribution.
- Jamais de contournement de protection, d'extraction de secrets ni de collecte de données personnelles, quel que soit l'objectif.
- Une reconstruction qui passe ses tests n'est équivalente à la référence que sur les comportements testés : ne pas l'annoncer comme « identique ».
