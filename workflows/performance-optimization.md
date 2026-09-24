# Workflow : Optimisation des performances

1. **Mesurer avant d'optimiser** : identifier le goulot d'étranglement réel (profiling, logs de requêtes lentes, métriques) plutôt que d'optimiser à l'intuition.
2. **Analyser** avec l'agent `performance` + skill `performance-audit` :
   - Requêtes N+1, index manquants, transactions trop larges (voir skill `database-design`)
   - Cache absent ou mal invalidé
   - Appels réseau redondants ou séquentiels qui pourraient être parallélisés
   - Chargement eager/lazy mal calibré (trop de données chargées d'un coup, ou trop d'allers-retours)
   - Taille des payloads (pagination, sur-fetching de champs inutiles)
3. **Prioriser** par gain estimé × fréquence d'exécution (optimiser un chemin exécuté une fois par jour a moins d'impact qu'un chemin exécuté à chaque requête).
4. **Optimiser** un point à la fois, en mesurant l'effet réel après chaque changement.
5. **Vérifier l'absence de régression fonctionnelle** (les tests existants doivent toujours passer).
6. **Documenter** le gain mesuré (avant/après) dans la description de la PR.

## Points d'attention

- Ne pas complexifier le code pour un gain marginal non mesuré — voir [dry-kiss-yagni.md](../standards/dry-kiss-yagni.md).
- Une optimisation qui sacrifie la lisibilité doit être justifiée par une mesure concrète et documentée en commentaire (le "pourquoi" de ce code moins lisible).
