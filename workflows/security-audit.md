# Workflow : Audit de sécurité

1. **Détecter la stack** (skill `stack-detection`) — les vecteurs d'attaque pertinents dépendent du langage/framework (ex. injection SQL brute vs ORM, XSS côté SPA vs rendu serveur).
2. **Auditer** avec l'agent `security` + skill `security-audit`, en suivant systématiquement [owasp-top10.md](../standards/owasp-top10.md) :
   - Authentification et gestion de session
   - Autorisation (contrôle d'accès par ressource, pas seulement par route)
   - Validation des entrées (injection, XSS, path traversal, SSRF)
   - Gestion des secrets et de la configuration
   - Dépendances vulnérables/obsolètes
3. **Prioriser les constats** par sévérité réelle (exploitabilité × impact), pas par facilité de correction.
4. **Reporter** chaque constat avec fichier:ligne, scénario d'exploitation concret, et correctif proposé — pas de généralité type "améliorer la sécurité".
5. **Corriger** les constats critiques/élevés en priorité (agent `backend`/`api` selon la couche), puis enchaîner sur `/workflow bug-fix` pour chaque correctif avec un test de non-régression.
6. **Ne jamais publier** de preuve de concept d'exploitation fonctionnelle dans un rapport partagé largement — décrire le mécanisme, pas fournir un exploit clé en main.

## Points d'attention

- Un audit de sécurité est un contexte d'usage défensif/autorisé (test interne, revue de code du propre projet) — pas une reconnaissance offensive sur un système tiers sans autorisation.
