# Workflow : Refactoring

1. **Garantir un filet de sécurité** : vérifier qu'il existe des tests couvrant le comportement actuel du code à refactorer. En ajouter avant de toucher au code si la couverture est insuffisante (agent `testing`).
2. **Identifier les cibles** : agent `refactoring` + skill `refactoring-guide` — duplication, complexité excessive, responsabilités mélangées (voir [solid.md](../standards/solid.md), [clean-code.md](../standards/clean-code.md)).
3. **Refactorer par petites étapes**, chacune vérifiable indépendamment (extraction de méthode, renommage, déplacement) — éviter un refactoring monolithique difficile à réviser.
4. **Vérifier après chaque étape** que les tests passent toujours et que le comportement observable n'a pas changé.
5. **Revue finale** : skill `code-quality` sur le résultat.
6. **Commit** : `refactor(...)` ([message-commit.md](../templates/message-commit.md)) — jamais mélangé avec un `feat` ou un `fix` dans le même commit.

## Points d'attention

- Un refactoring ne doit jamais changer le comportement observable. Si un changement de comportement est nécessaire, c'est un `feat`/`fix` séparé.
- Ne pas refactorer au-delà du périmètre demandé ("pendant que j'y suis") sans accord — cela complique la revue et le diff.
