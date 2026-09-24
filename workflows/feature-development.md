# Workflow : Développement d'une nouvelle fonctionnalité

1. **Détecter la stack** (skill `stack-detection`) si pas déjà fait dans la session.
2. **Clarifier le besoin** : cas d'usage, critères d'acceptation, périmètre exclu. Poser des questions si l'intention est ambiguë plutôt que de deviner.
3. **Analyse d'impact architecture** : agent `architect` — où cette fonctionnalité s'insère-t-elle, quels modules touche-t-elle, faut-il un nouveau découpage ?
4. **Conception si nécessaire** :
   - Nouvelle API/endpoint → agent `api` + skill `api-design`.
   - Nouveau schéma de données → agent `database` + skill `database-design`.
5. **Implémentation** : agents `backend`/`frontend` selon la couche concernée, en réutilisant l'existant (ne pas dupliquer une fonction déjà présente).
6. **Tests** : agent `testing` + skill `test-strategy` — au minimum les cas nominaux et les cas limites identifiés à l'étape 2.
7. **Revue** : skill `code-quality` (et `security-audit` si la fonctionnalité touche à l'authentification, aux permissions ou à des données sensibles).
8. **Documentation** : agent `documentation` si la fonctionnalité change un comportement visible (README, changelog via [entree-changelog.md](../templates/entree-changelog.md)).
9. **Préparation PR** : enchaîner avec `/workflow pr-preparation`.

## Points d'attention

- Ne pas sur-concevoir une fonctionnalité simple (voir [dry-kiss-yagni.md](../standards/dry-kiss-yagni.md)).
- Vérifier qu'aucune fonction/util équivalente n'existe déjà avant d'en écrire une nouvelle.
