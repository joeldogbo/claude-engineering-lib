# Workflow : Développement d'une nouvelle fonctionnalité

1. **Détecter la stack** (skill `stack-detection`) si pas déjà fait dans la session.
2. **Clarifier le besoin** : cas d'usage, critères d'acceptation, périmètre exclu. Poser des questions si l'intention est ambiguë plutôt que de deviner.
3. **Analyse d'impact architecture** : agent `architect` — où cette fonctionnalité s'insère-t-elle, quels modules touche-t-elle, faut-il un nouveau découpage ?
4. **Conception si nécessaire** :
   - Nouvelle API/endpoint → agent `api` + skill `api-design`.
   - Nouveau schéma de données → agent `database` + skill `database-design`.
5. **Règles d'accès avant le code client** : si la fonctionnalité expose ou modifie des données, définir d'abord côté serveur qui a le droit de lire/écrire quoi et quelles données sont validées — selon la stack : middleware ou policy, guard, permissions, règles de sécurité d'un BaaS (Firebase, Supabase...). L'interface ne sert jamais de contrôle d'accès.
6. **Implémentation** : agents `backend`/`frontend` selon la couche concernée, en réutilisant l'existant (ne pas dupliquer une fonction déjà présente). Préciser quelle application est touchée quand le dépôt en contient plusieurs (site public, back-office, mobile...).
7. **Tests** : agent `testing` + skill `test-strategy` — au minimum les cas nominaux et les cas limites identifiés à l'étape 2, plus un test **autorisé** et un test **refusé** pour chaque règle d'accès de l'étape 5.
8. **Revue** : skill `code-quality` (et `security-audit` si la fonctionnalité touche à l'authentification, aux permissions ou à des données sensibles).
9. **Documentation** : agent `documentation` si la fonctionnalité change un comportement visible ou le modèle de données (README, changelog via [entree-changelog.md](../templates/entree-changelog.md)).
10. **Rapport final** : ce qui a été fait, fichiers touchés, tests ajoutés, points restés ouverts.
11. **Préparation PR** : enchaîner avec `/workflow pr-preparation`.

**Fail-fast** : si une étape échoue (tests rouges, règle d'accès impossible à définir, revue bloquante), s'arrêter et le signaler plutôt que de poursuivre les étapes suivantes.

## Points d'attention

- Ne pas sur-concevoir une fonctionnalité simple (voir [dry-kiss-yagni.md](../standards/dry-kiss-yagni.md)).
- Vérifier qu'aucune fonction/util équivalente n'existe déjà avant d'en écrire une nouvelle.
