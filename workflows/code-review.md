# Workflow : Revue de code

1. **Détecter la stack** si nécessaire pour appliquer les bonnes conventions.
2. **Obtenir le diff et cartographier** : si ni diff ni PR/MR n'est fourni, comparer la branche à la branche principale (`git diff <branche-principale>...HEAD`). Lister les fichiers modifiés et le rôle de chacun dans le projet avant d'entrer dans le détail.
3. **Revue fonctionnelle** : le code fait-il ce que la description de la PR annonce ? Les cas limites mentionnés sont-ils couverts par des tests ?
4. **Revue qualité** : agent `code-reviewer` + skill `code-quality` — lisibilité, duplication, complexité, conventions du projet, commentaires inutiles ou manquants.
5. **Revue architecture** (si le changement est structurant) : agent `architect` + skill `architecture-review`.
6. **Revue sécurité** (si le changement touche auth/permissions/règles d'accès/données sensibles/entrées utilisateur) : agent `security` + skill `security-audit`.
7. **Revue performance** (si le changement touche une boucle chaude, une requête BDD, un endpoint à fort trafic) : skill `performance-audit`.
8. **Classer les constats** par sévérité (bloquant / à corriger / suggestion facultative), avec fichier:ligne et scénario concret pour chacun — pas de remarque vague.
9. **Vérifier les tests** : couvrent-ils les cas nominaux et les cas limites introduits par ce changement, et les règles d'accès modifiées (un cas autorisé, un cas refusé) ?

## Format de restitution

1. **Verdict** en tête : ✅ Approuvé / ⚠️ Approuvé avec réserves / ❌ Changements requis.
2. **Constats** du plus sévère au moins sévère, chacun avec : fichier:ligne, description du problème concret, scénario de défaillance (entrée/état → sortie incorrecte), et correctif suggéré si évident.
3. **Points positifs** notables, brièvement — utiles pour savoir ce qu'il faut conserver.
