# Workflow : Correction de bug

1. **Reproduire** le bug de façon fiable — utiliser le gabarit [rapport-bug.md](../templates/rapport-bug.md) si les informations manquent (étapes, environnement, fréquence).
2. **Isoler la cause racine** : agent `debugging` + skill `debugging-methodology`. Ne pas s'arrêter au premier symptôme corrigeable superficiellement.
3. **Vérifier la portée** : le même bug existe-t-il ailleurs dans le code par un pattern similaire (grep ciblé) ?
4. **Corriger à la racine**, pas seulement le symptôme observé. Si un correctif superficiel est temporairement nécessaire, le documenter explicitement comme tel.
5. **Test de non-régression** : ajouter un test qui aurait échoué avant le correctif et qui passe après (agent `testing`).
6. **Vérifier l'absence de régression** ailleurs (lancer la suite de tests existante, pas seulement le nouveau test).
7. **Commit** : `fix(...)` suivant [message-commit.md](../templates/message-commit.md), en expliquant la cause racine dans le corps du message.

## Points d'attention

- Un bug de sécurité (auth, permissions, exposition de données) doit systématiquement enchaîner avec le skill `security-audit` avant de considérer le correctif complet.
- Ne jamais supprimer un test qui échoue pour "faire passer" la CI — corriger le code ou corriger le test s'il était mal écrit, jamais le contourner.
