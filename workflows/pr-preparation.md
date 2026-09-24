# Workflow : Préparation d'une Pull Request

1. **Revue personnelle du diff** avant publication : `git diff`/`git status` — vérifier qu'aucun fichier non voulu (secret, fichier temporaire, config locale) n'est inclus.
2. **Auto-revue qualité** : enchaîner rapidement avec `/workflow code-review` sur son propre changement.
3. **Vérifier les tests** : la suite pertinente passe localement.
4. **Rédiger la description** avec le gabarit [pr-description.md](../templates/pr-description.md) — résumé du "pourquoi", plan de test, risques.
5. **Vérifier les commits** : messages conformes à [message-commit.md](../templates/message-commit.md) ; squasher les commits de type "wip"/"fix typo" qui n'apportent rien à l'historique si l'équipe préfère un historique propre.
6. **Mettre à jour la documentation/changelog** si le comportement visible change ([entree-changelog.md](../templates/entree-changelog.md)).
7. **Vérifier le périmètre** : la PR ne mélange pas plusieurs sujets sans rapport — si c'est le cas, proposer de la scinder.
8. **Ouvrir la PR** seulement après confirmation explicite de l'utilisateur (action visible par d'autres — voir règles de prudence sur les actions à fort impact).

## Points d'attention

- Ne jamais pousser ou ouvrir une PR sans une demande explicite de l'utilisateur pour cette action précise.
