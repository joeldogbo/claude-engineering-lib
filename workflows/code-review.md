# Workflow : Revue de code

1. **Détecter la stack** si nécessaire pour appliquer les bonnes conventions.
2. **Revue fonctionnelle** : le code fait-il ce que la description de la PR annonce ? Les cas limites mentionnés sont-ils couverts par des tests ?
3. **Revue qualité** : agent `code-reviewer` + skill `code-quality` — lisibilité, duplication, complexité, conventions du projet, commentaires inutiles ou manquants.
4. **Revue architecture** (si le changement est structurant) : agent `architect` + skill `architecture-review`.
5. **Revue sécurité** (si le changement touche auth/permissions/données sensibles/entrées utilisateur) : skill `security-audit`.
6. **Revue performance** (si le changement touche une boucle chaude, une requête BDD, un endpoint à fort trafic) : skill `performance-audit`.
7. **Classer les constats** par sévérité (bloquant / à corriger / suggestion facultative), avec fichier:ligne et scénario concret pour chacun — pas de remarque vague.
8. **Vérifier les tests** : couvrent-ils les cas nominaux et les cas limites introduits par ce changement ?

## Format de restitution

Constats du plus sévère au moins sévère, chacun avec : fichier:ligne, description du problème concret, scénario de défaillance (entrée/état → sortie incorrecte), et correctif suggéré si évident.
