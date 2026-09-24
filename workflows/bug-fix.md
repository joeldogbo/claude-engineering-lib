# Workflow : Correction de bug

1. **Reproduire** le bug de façon fiable — utiliser le gabarit [rapport-bug.md](../templates/rapport-bug.md) si les informations manquent (étapes, environnement, fréquence).
2. **Isoler la cause racine** : agent `debugging` + skill `debugging-methodology`. Ne pas s'arrêter au premier symptôme corrigeable superficiellement. **Fail-fast** : tant que la cause n'est pas localisée (fichier:ligne) **et prouvée** (reproduction, log, trace, test qui échoue), on ne corrige pas — on présente les hypothèses restantes et ce qui permettrait de trancher.
3. **Vérifier la portée** : le même bug existe-t-il ailleurs dans le code par un pattern similaire (grep ciblé) ?
4. **Corriger à la racine**, pas seulement le symptôme observé, avec un **correctif minimal et ciblé** : pas de refactoring connexe dans le même changement (le proposer à part via `/workflow refactoring`). Si un correctif superficiel est temporairement nécessaire, le documenter explicitement comme tel.
5. **Test de non-régression** : ajouter un test qui aurait échoué avant le correctif et qui passe après (agent `testing`).
6. **Vérifier l'absence de régression** ailleurs (lancer la suite de tests existante, pas seulement le nouveau test).
7. **Revue** : agent `code-reviewer` sur le correctif, pour vérifier qu'il ne dégrade rien d'autre.
8. **Changelog** : entrée ([entree-changelog.md](../templates/entree-changelog.md)) si le bug était visible par les utilisateurs (agent `documentation`).
9. **Commit** : `fix(...)` suivant [message-commit.md](../templates/message-commit.md), en expliquant la cause racine dans le corps du message.

## Points d'attention

- Un bug de sécurité (auth, permissions, exposition de données) doit systématiquement enchaîner avec le skill `security-audit` avant de considérer le correctif complet.
- Ne jamais supprimer un test qui échoue pour "faire passer" la CI — corriger le code ou corriger le test s'il était mal écrit, jamais le contourner.
