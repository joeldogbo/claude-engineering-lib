# PSR (PHP Standards Recommendations)

**À appliquer uniquement si PHP est détecté dans le projet** (présence de `composer.json`).

## PSR-1 / PSR-12 — style de code

- Balises `<?php` (pas de balise courte), un seul namespace par fichier, `UpperCamelCase` pour les classes, `camelCase` pour les méthodes, `UPPER_SNAKE_CASE` pour les constantes.
- Indentation 4 espaces, pas de tabulation ; accolade d'ouverture des classes/méthodes sur sa propre ligne.
- Une seule instruction par ligne ; visibilité (`public`/`protected`/`private`) déclarée explicitement sur toutes les propriétés/méthodes.
- La plupart des projets modernes appliquent ces règles via un formateur automatique (ex. Laravel Pint, PHP-CS-Fixer) plutôt qu'à la main — vérifier s'il y en a un configuré avant de reformater manuellement.

## PSR-4 — autoloading

- Une classe = un fichier, chemin déductible du namespace (`App\Services\FooService` → `app/Services/FooService.php` selon le mapping de `composer.json`).

## PSR-3 — interface de logging

- Les niveaux de log (`emergency` à `debug`) ont une sémantique précise ; ne pas tout logger en `error` par facilité.

## PSR-7 / PSR-15 (si présents) — HTTP

- Requêtes/réponses HTTP immuables, middlewares comme pipeline de traitement — pertinent surtout hors frameworks qui ont leur propre couche HTTP (Laravel/Symfony ont leurs abstractions dédiées, généralement à préférer à une implémentation PSR-7 manuelle sauf besoin d'interopérabilité).

## Dans le contexte d'un framework (Laravel, Symfony...)

Le framework impose déjà ses propres conventions (souvent alignées sur PSR). Toujours privilégier la convention du framework détecté quand elle diverge légèrement d'un PSR générique — la cohérence avec le reste du code prime.
